%% FAZ 4 - Hareket Algılama Testi
% Amaç: Faz 3'te kaydettiğimiz "boş oda" baseline'ı ile şimdi
% GERÇEKTEN HAREKET EDEREK topladığımız veriyi karşılaştırmak.
%
% Kullanım:
%   1) Bu scripti çalıştır
%   2) "Kayıt başladı" yazınca odada yürü / el salla / hareket et
%   3) Script bitince iki grafik göreceksin: baseline (mavi) vs
%      hareketli kayıt (kırmızı) üst üste
%   4) Konsolda otomatik önerilen bir eşik (threshold) değeri göreceksin

clear; clc; close all;

%% --- Baseline'ı yükle ---
if ~isfile('pluto_baseline_bos_oda.mat')
    error('Önce faz3_surekli_veri_baseline.m''i çalıştırıp baseline kaydetmelisin.');
end
load('pluto_baseline_bos_oda.mat', 'baseline', 'tonePhase', 'tonePowerDB');

% Baseline'ın kayan pencere faz varyansını yeniden hesapla (referans eğri için)
windowSize = baseline.windowSize;
N_base = numel(tonePhase);
basePhaseVar = nan(1, N_base);
for j = windowSize:N_base
    basePhaseVar(j) = var(unwrap(tonePhase(j-windowSize+1:j)));
end

%% --- RF parametreleri (baseline ile birebir aynı olmalı!) ---
centerFreq   = baseline.centerFreq;
sampleRate   = baseline.sampleRate;
toneOffset   = baseline.toneOffset;
txGain       = baseline.txGain;
rxGain       = baseline.rxGain;
frameLen     = baseline.frameLen;

recordSeconds = 20;
frameDuration = frameLen / sampleRate;
numFrames     = ceil(recordSeconds / frameDuration);

%% --- TX sinyali ---
t = (0:frameLen-1)' / sampleRate;
txWaveform = 0.5 * exp(1j * 2 * pi * toneOffset * t);

%% --- Pluto TX/RX ---
tx = sdrtx('Pluto', 'CenterFrequency', centerFreq, ...
    'BasebandSampleRate', sampleRate, 'Gain', txGain);
rx = sdrrx('Pluto', 'CenterFrequency', centerFreq, ...
    'BasebandSampleRate', sampleRate, 'SamplesPerFrame', frameLen, ...
    'GainSource', 'Manual', 'Gain', rxGain, 'OutputDataType', 'double');

fprintf('TX başlatılıyor...\n');
transmitRepeat(tx, txWaveform);
pause(0.5);

NFFT = frameLen;
f = (-NFFT/2:NFFT/2-1) * (sampleRate/NFFT);
[~, toneBinIdx] = min(abs(f - toneOffset));

%% --- Geri sayım ---
fprintf('\n>>> HAZIRLAN! Kayıt başlayınca ODADA HAREKET ET (yürü, el salla vb.) <<<\n');
fprintf('3...\n'); pause(1);
fprintf('2...\n'); pause(1);
fprintf('1...\n'); pause(1);
fprintf('KAYIT BAŞLADI - ŞİMDİ HAREKET ET!\n');

tonePowerDB_move = nan(1, numFrames);
tonePhase_move   = nan(1, numFrames);
timeAxis = (0:numFrames-1) * frameDuration;

for k = 1:numFrames
    rxData = rx();
    RX_FFT = fftshift(fft(rxData, NFFT));
    toneComplex = RX_FFT(toneBinIdx);
    tonePowerDB_move(k) = 20*log10(abs(toneComplex) + eps);
    tonePhase_move(k)   = angle(toneComplex);
end

release(tx);
release(rx);
fprintf('Kayıt tamamlandı. TX/RX durduruldu.\n');

%% --- Hareketli kaydın faz varyansını hesapla ---
movePhaseVar = nan(1, numFrames);
for j = windowSize:numFrames
    movePhaseVar(j) = var(unwrap(tonePhase_move(j-windowSize+1:j)));
end

%% --- Karşılaştırma grafiği ---
figure('Name', 'FAZ 4 - Baseline vs Hareket');

subplot(2,1,1);
plot((0:N_base-1)*frameDuration, tonePowerDB, 'b-', 'LineWidth', 1); hold on;
plot(timeAxis, tonePowerDB_move, 'r-', 'LineWidth', 1);
legend('Baseline (boş oda)', 'Hareketli kayıt', 'Location', 'best');
xlabel('Zaman (sn)'); ylabel('Ton Gücü (dB)');
title('Ton Gücü Karşılaştırması');
grid on;

subplot(2,1,2);
plot((0:N_base-1)*frameDuration, basePhaseVar, 'b-', 'LineWidth', 1); hold on;
plot(timeAxis, movePhaseVar, 'r-', 'LineWidth', 1);
legend('Baseline (boş oda)', 'Hareketli kayıt', 'Location', 'best');
xlabel('Zaman (sn)'); ylabel('Faz Varyansı');
title('Faz Varyansı Karşılaştırması - Asıl Hareket Göstergesi');
grid on;

%% --- Otomatik eşik önerisi ---
baseMean = mean(basePhaseVar, 'omitnan');
baseStd  = std(basePhaseVar, 'omitnan');
baseMax  = max(basePhaseVar);

moveMean = mean(movePhaseVar, 'omitnan');
moveMax  = max(movePhaseVar);

% Eşik: baseline ortalamasının üzerine birkaç std ekleyerek belirle
suggestedThreshold = baseMean + 4*baseStd;

fprintf('\n--- HAREKET ALGILAMA ANALİZİ ---\n');
fprintf('Baseline  -> ortalama: %.2f | std: %.2f | maksimum: %.2f\n', baseMean, baseStd, baseMax);
fprintf('Hareketli -> ortalama: %.2f | maksimum: %.2f\n', moveMean, moveMax);
fprintf('Önerilen eşik (threshold): %.2f\n', suggestedThreshold);

if moveMax > suggestedThreshold
    fprintf('✓ Hareketli kayıtta eşiği aşan değerler var -> HAREKET ALGILANABİLİR.\n');
    fprintf('  Eşiği aşan frame oranı: %.1f%%\n', ...
        100*sum(movePhaseVar > suggestedThreshold, 'omitnan')/sum(~isnan(movePhaseVar)));
else
    fprintf('⚠ Hareketli kayıt eşiği aşmadı. Daha büyük/yakın hareket dene ya da rxGain''i artır.\n');
end
fprintf('----------------------------------\n');

%% --- Kaydet ---
save('pluto_hareket_testi.mat', 'tonePowerDB_move', 'tonePhase_move', ...
    'movePhaseVar', 'suggestedThreshold', 'baseMean', 'baseStd');
fprintf('Sonuçlar "pluto_hareket_testi.mat" dosyasına kaydedildi.\n');
