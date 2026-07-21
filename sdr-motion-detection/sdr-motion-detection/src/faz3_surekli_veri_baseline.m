%% FAZ 3 - Sürekli Veri Toplama, Gerçek Zamanlı İzleme ve Baseline Kaydı
% Amaç:
%   1) TX sürekli ton gönderirken RX'ten sürekli veri akışı alıp
%      gerçek zamanlı olarak izlemek (canlı spektrum + güç/faz grafiği)
%   2) ODA BOŞKEN (kimse hareket etmiyorken) bir "baseline" (referans)
%      kaydı almak ve .mat dosyasına kaydetmek.
%
% Bu baseline, Faz 4'te "hareket var mı yok mu" kararını verirken
% karşılaştırma noktamız olacak: canlı sinyal baseline'dan ne kadar
% saparsa, o kadar "hareket" ihtimali var demektir.
%
% ÖNEMLİ: Bu scripti çalıştırırken ODADA KİMSE HAREKET ETMESİN.
% Kayıt bitene kadar sabit dur / odadan çık.

clear; clc; close all;

%% --- Parametreler (Faz 2 ile aynı RF ayarları) ---
centerFreq   = 2.4e9;
sampleRate   = 2e6;
toneOffset   = 100e3;
txGain       = -10;
rxGain       = 30;
frameLen     = 4096;

recordSeconds = 20;   % Ne kadar süre baseline kaydedeceğiz
frameDuration = frameLen / sampleRate;         % Bir frame'in süresi (sn)
numFrames     = ceil(recordSeconds / frameDuration);

windowSize    = 20;   % Kayan pencere: son kaç frame üzerinden özellik hesaplansın

%% --- TX sinyali (offset'li CW ton, Faz 2 ile aynı) ---
t = (0:frameLen-1)' / sampleRate;
txWaveform = 0.5 * exp(1j * 2 * pi * toneOffset * t);

%% --- Pluto TX/RX objeleri ---
tx = sdrtx('Pluto', ...
    'CenterFrequency', centerFreq, ...
    'BasebandSampleRate', sampleRate, ...
    'Gain', txGain);

rx = sdrrx('Pluto', ...
    'CenterFrequency', centerFreq, ...
    'BasebandSampleRate', sampleRate, ...
    'SamplesPerFrame', frameLen, ...
    'GainSource', 'Manual', ...
    'Gain', rxGain, ...
    'OutputDataType', 'double');

%% --- TX başlat ---
fprintf('TX başlatılıyor...\n');
transmitRepeat(tx, txWaveform);
pause(0.5);

%% --- Gerçek zamanlı izleme için figür hazırla ---
fig = figure('Name', 'FAZ 3 - Canlı İzleme');

subplot(2,1,1);
hPower = plot(nan, nan, 'b-', 'LineWidth', 1.2);
xlabel('Zaman (sn)'); ylabel('Ton Gücü (dB)');
title('Kayan Pencere: Ton Gücü (Hareket Sezgisi İçin)');
grid on;

subplot(2,1,2);
hPhase = plot(nan, nan, 'r-', 'LineWidth', 1.2);
xlabel('Zaman (sn)'); ylabel('Faz Varyansı');
title('Kayan Pencere: Faz Varyansı');
grid on;

%% --- Sürekli veri toplama döngüsü ---
fprintf('Baseline kaydı başlıyor (%d saniye). ODADA HAREKET ETME!\n', recordSeconds);
fprintf('3...\n'); pause(1);
fprintf('2...\n'); pause(1);
fprintf('1...\n'); pause(1);
fprintf('Kayıt başladı.\n');

rawIQ       = zeros(frameLen, numFrames);
tonePowerDB = nan(1, numFrames);
tonePhase   = nan(1, numFrames);
timeAxis    = (0:numFrames-1) * frameDuration;

% Ton frekansındaki bin'i bulmak için FFT indeksi hesapla
NFFT = frameLen;
f = (-NFFT/2:NFFT/2-1) * (sampleRate/NFFT);
[~, toneBinIdx] = min(abs(f - toneOffset));

for k = 1:numFrames
    rxData = rx();
    rawIQ(:,k) = rxData;

    % Ton frekansındaki genlik ve fazı çıkar
    RX_FFT = fftshift(fft(rxData, NFFT));
    toneComplex = RX_FFT(toneBinIdx);
    tonePowerDB(k) = 20*log10(abs(toneComplex) + eps);
    tonePhase(k)   = angle(toneComplex);

    % Her windowSize frame'de bir grafiği güncelle (performans için)
    if mod(k, 5) == 0 || k == numFrames
        validIdx = 1:k;
        set(hPower, 'XData', timeAxis(validIdx), 'YData', tonePowerDB(validIdx));
        subplot(2,1,1); xlim([0, recordSeconds]);

        % Kayan pencere faz varyansı
        phaseVar = nan(1,k);
        for j = windowSize:k
            phaseVar(j) = var(unwrap(tonePhase(j-windowSize+1:j)));
        end
        set(hPhase, 'XData', timeAxis(validIdx), 'YData', phaseVar(validIdx));
        subplot(2,1,2); xlim([0, recordSeconds]);

        drawnow limitrate;
    end
end

%% --- TX/RX durdur ---
release(tx);
release(rx);
fprintf('Kayıt tamamlandı. TX/RX durduruldu.\n');

%% --- Baseline istatistiklerini hesapla ---
baseline.tonePowerDB_mean = mean(tonePowerDB);
baseline.tonePowerDB_std  = std(tonePowerDB);
baseline.phaseVar_mean    = mean(phaseVar(windowSize:end), 'omitnan');
baseline.phaseVar_std     = std(phaseVar(windowSize:end), 'omitnan');
baseline.toneOffset       = toneOffset;
baseline.sampleRate       = sampleRate;
baseline.frameLen         = frameLen;
baseline.centerFreq       = centerFreq;
baseline.rxGain           = rxGain;
baseline.txGain           = txGain;
baseline.windowSize       = windowSize;
baseline.recordDate       = datetime('now');

fprintf('\n--- BASELINE İSTATİSTİKLERİ ---\n');
fprintf('Ortalama ton gücü      : %.2f dB (std: %.2f)\n', baseline.tonePowerDB_mean, baseline.tonePowerDB_std);
fprintf('Ortalama faz varyansı  : %.5f (std: %.5f)\n', baseline.phaseVar_mean, baseline.phaseVar_std);
fprintf('--------------------------------\n');

%% --- Kaydet ---
save('pluto_baseline_bos_oda.mat', 'baseline', 'rawIQ', 'tonePowerDB', 'tonePhase', 'timeAxis');
fprintf('Baseline "pluto_baseline_bos_oda.mat" dosyasına kaydedildi.\n');
fprintf('Bu dosyayı Faz 4''te hareket algılama eşiklerini belirlemek için kullanacağız.\n');
