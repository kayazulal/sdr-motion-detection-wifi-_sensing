%% FAZ 5 (GUNCEL) - Guc Varyansi Tabanli Coklu Senaryo Kalibrasyonu
% ONCEKI BULGU: Faz varyansi, ornek kaybi/USB gecikmesi gibi donanimsal
% artefaktlardan asiri etkilendigi icin hareketi guvenilir sekilde
% ayirt edemedi (tum senaryolar ayni gurultu bandinda cikti).
%
% YENI YAKLASIM: Ana ozellik olarak GUC (genlik) varyansini kullaniyoruz.
% Guc, ornek kaybindan faz kadar etkilenmez - Faz 4'teki ham grafiklerde
% zaten guc ekseninde (48.15-48.19 vs 48.15-48.40 dB) anlamli bir fark
% gormustuk. Ayrica her rx() cagrisi arasindaki gecikmeyi olcup olasi
% donanim kaynakli anormallikleri de loglayacagiz.
%
% Faz varyansini da hesaplayip kaydediyoruz (karsilastirma icin), ama
% karar/esik icin GUC VARYANSINI esas alacagiz.


clear; clc; close all;

%% --- Senaryo tanimlari ---
scenarios = {
    'bos_oda_2',      'ODADAN CIK veya TAMAMEN SABIT DUR (tekrar bos-oda testi)'
    'yakin_hareket',  'PLUTOYA YAKIN (~0.5-1m) MESAFEDE YURU / EL SALLA'
    'uzak_hareket',   'PLUTODAN UZAK (~3-4m) MESAFEDE YURU / EL SALLA'
    'yavas_hareket',  'AYNI MESAFEDE (~1.5m) COK YAVAS/KUCUK HAREKET (el/parmak)'
    'hizli_hareket',  'AYNI MESAFEDE (~1.5m) HIZLI/BUYUK HAREKET (kol sallama, adim)'
};

recordSeconds = 15;

%% --- Baseline'dan RF parametrelerini al ---
if ~isfile('pluto_baseline_bos_oda.mat')
    error('Once faz3_surekli_veri_baseline.m calistirmalisin.');
end
load('pluto_baseline_bos_oda.mat', 'baseline');

centerFreq   = baseline.centerFreq;
sampleRate   = baseline.sampleRate;
toneOffset   = baseline.toneOffset;
txGain       = baseline.txGain;
rxGain       = baseline.rxGain;
frameLen     = baseline.frameLen;
windowSize   = baseline.windowSize;

frameDuration = frameLen / sampleRate;
numFrames     = ceil(recordSeconds / frameDuration);

t = (0:frameLen-1)' / sampleRate;
txWaveform = 0.5 * exp(1j * 2 * pi * toneOffset * t);

NFFT = frameLen;
f = (-NFFT/2:NFFT/2-1) * (sampleRate/NFFT);
[~, toneBinIdx] = min(abs(f - toneOffset));

%% --- Pluto TX/RX kur ---
tx = sdrtx('Pluto', 'CenterFrequency', centerFreq, ...
    'BasebandSampleRate', sampleRate, 'Gain', txGain);
rx = sdrrx('Pluto', 'CenterFrequency', centerFreq, ...
    'BasebandSampleRate', sampleRate, 'SamplesPerFrame', frameLen, ...
    'GainSource', 'Manual', 'Gain', rxGain, 'OutputDataType', 'double');

fprintf('TX baslatiliyor (kalibrasyon boyunca surekli acik kalacak)...\n');
transmitRepeat(tx, txWaveform);
pause(0.5);

%% --- Her senaryo icin veri topla ---
numScenarios = size(scenarios, 1);
calibData = struct();
expectedFrameTime = frameDuration; % bir frame'in "olmasi gereken" suresi

for s = 1:numScenarios
    label = scenarios{s,1};
    instruction = scenarios{s,2};

    fprintf('\n========================================\n');
    fprintf('SENARYO %d/%d: %s\n', s, numScenarios, label);
    fprintf('TALIMAT: %s\n', instruction);
    fprintf('========================================\n');
    input('Hazir oldugunda ENTERa bas (kayit hemen ardindan baslar)...', 's');

    fprintf('3...\n'); pause(1);
    fprintf('2...\n'); pause(1);
    fprintf('1...\n'); pause(1);
    fprintf('KAYIT BASLADI - %s\n', instruction);

    tonePowerDB_s = nan(1, numFrames);
    tonePhase_s   = nan(1, numFrames);
    callDelay_s   = nan(1, numFrames); % rx() cagrilari arasi gercek sure

    tPrev = tic;
    for k = 1:numFrames
        rxData = rx();
        callDelay_s(k) = toc(tPrev);
        tPrev = tic;

        RX_FFT = fftshift(fft(rxData, NFFT));
        toneComplex = RX_FFT(toneBinIdx);
        tonePowerDB_s(k) = 20*log10(abs(toneComplex) + eps);
        tonePhase_s(k)   = angle(toneComplex);
    end

    fprintf('Kayit bitti.\n');

    % Kayan pencere ile GUC varyansi (asil ozelligimiz)
    powerVar_s = nan(1, numFrames);
    for j = windowSize:numFrames
        powerVar_s(j) = var(tonePowerDB_s(j-windowSize+1:j));
    end

    % Kayan pencere ile FAZ varyansi (karsilastirma icin, karar vermede kullanilmayacak)
    phaseVar_s = nan(1, numFrames);
    for j = windowSize:numFrames
        phaseVar_s(j) = var(unwrap(tonePhase_s(j-windowSize+1:j)));
    end

    % Zamanlama anomalisi tespiti: beklenenden %50+ yavas rx() cagrisi
    % olasi ornek kaybi/USB gecikmesi isareti olabilir
    anomalyCount = sum(callDelay_s > 1.5*expectedFrameTime, 'omitnan');
    anomalyPct = 100 * anomalyCount / numFrames;

    calibData.(label).tonePowerDB = tonePowerDB_s;
    calibData.(label).tonePhase   = tonePhase_s;
    calibData.(label).powerVar    = powerVar_s;
    calibData.(label).phaseVar    = phaseVar_s;
    calibData.(label).callDelay   = callDelay_s;
    calibData.(label).anomalyPct  = anomalyPct;

    calibData.(label).powerVar_mean   = mean(powerVar_s, 'omitnan');
    calibData.(label).powerVar_std    = std(powerVar_s, 'omitnan');
    calibData.(label).powerVar_max    = max(powerVar_s);
    calibData.(label).powerVar_median = median(powerVar_s, 'omitnan');

    fprintf('  -> Guc varyansi ort: %.4f | max: %.4f | zamanlama anomalisi: %.1f%%\n', ...
        calibData.(label).powerVar_mean, calibData.(label).powerVar_max, anomalyPct);
end

%% --- TX/RX durdur ---
release(tx);
release(rx);
fprintf('\nTum senaryolar tamamlandi. TX/RX durduruldu.\n');

%% --- Ozet tablo ---
fprintf('\n--- KALIBRASYON OZET TABLOSU (GUC Varyansi, dB^2) ---\n');
fprintf('%-16s %10s %10s %10s %10s %12s\n', 'Senaryo', 'Ortalama', 'Std', 'Medyan', 'Maksimum', 'Anomali%%');
labels = fieldnames(calibData);
for i = 1:numel(labels)
    d = calibData.(labels{i});
    fprintf('%-16s %10.4f %10.4f %10.4f %10.4f %12.1f\n', labels{i}, ...
        d.powerVar_mean, d.powerVar_std, d.powerVar_median, d.powerVar_max, d.anomalyPct);
end

%% --- Karsilastirma grafigi ---
figure('Name', 'FAZ 5 - Guc Varyansi Karsilastirmasi');

subplot(2,1,1);
colors = lines(numel(labels));
hold on;
for i = 1:numel(labels)
    d = calibData.(labels{i}).powerVar;
    tAxis = (0:numel(d)-1) * frameDuration;
    plot(tAxis, d, 'Color', colors(i,:), 'LineWidth', 1);
end
legend(labels, 'Interpreter', 'none', 'Location', 'bestoutside');
xlabel('Zaman (sn)'); ylabel('Guc Varyansi (dB^2)');
title('Senaryolara Gore Guc Varyansi Zaman Serisi');
grid on;

subplot(2,1,2);
means = zeros(1, numel(labels));
stds  = zeros(1, numel(labels));
maxs  = zeros(1, numel(labels));
for i = 1:numel(labels)
    means(i) = calibData.(labels{i}).powerVar_mean;
    stds(i)  = calibData.(labels{i}).powerVar_std;
    maxs(i)  = calibData.(labels{i}).powerVar_max;
end
bar(means, 'FaceColor', [0.3 0.6 0.9]); hold on;
errorbar(1:numel(labels), means, stds, 'k.', 'LineWidth', 1.2);
plot(1:numel(labels), maxs, 'r*', 'MarkerSize', 10, 'LineWidth', 1.5);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'TickLabelInterpreter', 'none');
xtickangle(30);
legend('Ortalama', 'Std (hata cubugu)', 'Maksimum (kirmizi yildiz)', 'Location', 'best');
ylabel('Guc Varyansi (dB^2)');
title('Senaryo Ozet Istatistikleri (Guc Varyansi)');
grid on;

%% --- Esik onerisi (manuel persentil, guc varyansi uzerinden) ---
emptyRoomData = calibData.bos_oda_2.powerVar;
emptyRoomData = emptyRoomData(~isnan(emptyRoomData));
sortedData = sort(emptyRoomData);
idx99 = ceil(0.99 * numel(sortedData));
robustThreshold = sortedData(idx99);

fprintf('\n--- ESIK ONERISI (Guc Varyansi Bazli) ---\n');
fprintf('Bos-oda guc varyansi 99. persentili: %.4f\n', robustThreshold);
for i = 1:numel(labels)
    d = calibData.(labels{i});
    pctAbove = 100 * sum(d.powerVar > robustThreshold, 'omitnan') / sum(~isnan(d.powerVar));
    fprintf('  %-16s esigi asan frame orani: %5.1f%%\n', labels{i}, pctAbove);
end

%% --- Zamanlama anomalisi ozeti (olasi ornek kaybi tanisi) ---
fprintf('\n--- ZAMANLAMA ANOMALISI OZETI ---\n');
fprintf('(Yuksek anomali%% = USB/donanim gecikmesi supheli, faz olcumlerini kirletebilir)\n');
for i = 1:numel(labels)
    fprintf('  %-16s : %.1f%%\n', labels{i}, calibData.(labels{i}).anomalyPct);
end

%% --- Kaydet ---
save('pluto_kalibrasyon_guc.mat', 'calibData', 'robustThreshold');
fprintf('\nKalibrasyon verisi "pluto_kalibrasyon_guc.mat" dosyasina kaydedildi.\n');
fprintf('Onerilen esik (guc varyansi): %.4f\n', robustThreshold);
