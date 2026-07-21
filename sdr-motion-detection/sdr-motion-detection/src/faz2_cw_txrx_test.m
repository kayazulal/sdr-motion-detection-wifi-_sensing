%% FAZ 2 - CW Ton TX/RX Testi ve Sızıntı Ölçümü
% Amaç: Pluto'dan sabit bir ton (CW, offset'li) gönderip aynı Pluto'nun
% RX tarafında yakalamak. Bu bize:
%   1) TX ve RX'in aynı anda (full duplex) çalıştığını doğrular
%   2) TX->RX sızıntı (self-interference) seviyesini ölçmemizi sağlar
%   3) Faz 4'teki hareket algılama için gürültü tabanını (noise floor)
%      belirlememizi sağlar
%
% NOT: TX ve RX anten/portlarını mümkün olduğunca farklı polarizasyonda
% (birbirine dik) tutmaya çalış, bu sızıntıyı azaltır.

clear; clc; close all;

%% --- Parametreler ---
centerFreq   = 2.4e9;      % Hoca önerisi: 2.4 GHz ISM bandı
sampleRate   = 2e6;        % 2 MHz baseband sample rate (başlangıç için yeterli)
toneOffset   = 100e3;      % Ton merkez frekanstan 100 kHz kaydırılmış
                            % (DC/LO sızıntısından ayırt edebilmek için)
txGain       = -10;        % dB, düşük başla (RX'i doygunlaştırmamak için)
rxGain       = 30;         % dB, RX gain (AGC kapalı, manuel başlıyoruz)
frameLen     = 4096;       % RX frame uzunluğu (örnek sayısı)
numFrames    = 50;         % Kaç frame okuyup analiz edeceğiz

%% --- TX sinyali oluştur: offset'li CW ton ---
t = (0:frameLen-1)' / sampleRate;
txWaveform = exp(1j * 2 * pi * toneOffset * t);   % kompleks CW ton
txWaveform = txWaveform * 0.5;                     % clipping'den kaçın

%% --- Pluto TX ve RX objelerini oluştur (full duplex) ---
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

%% --- Sürekli TX başlat ---
fprintf('TX başlatılıyor (sürekli ton gönderimi)...\n');
transmitRepeat(tx, txWaveform);
pause(0.5); % TX'in oturması için kısa bekleme

%% --- RX ile veri topla ---
fprintf('RX veri topluyor (%d frame)...\n', numFrames);
rxBuffer = zeros(frameLen, numFrames);
for k = 1:numFrames
    rxBuffer(:,k) = rx();
end

%% --- TX'i durdur ---
release(tx);
release(rx);
fprintf('TX/RX durduruldu.\n');

%% --- Analiz: Spektrum (FFT) ---
rxSignal = rxBuffer(:,end); % son frame üzerinden bakalım
NFFT = 4096;
f = (-NFFT/2:NFFT/2-1) * (sampleRate/NFFT);
RX_FFT = fftshift(fft(rxSignal, NFFT));
RX_dB = 20*log10(abs(RX_FFT) + eps);

figure('Name','FAZ 2 - Spektrum Analizi');
plot(f/1e3, RX_dB);
xlabel('Frekans Offset (kHz)');
ylabel('Genlik (dB)');
title('RX Spektrumu - TX Ton Sızıntısı Görünür Olmalı');
grid on;
xline(toneOffset/1e3, 'r--', 'Beklenen Ton');

%% --- Analiz: Spectrogram (zaman-frekans) ---
figure('Name','FAZ 2 - Spectrogram');
rxSignalLong = rxBuffer(:); % tüm frame'leri birleştir
spectrogram(rxSignalLong, 256, 200, 256, sampleRate, 'yaxis');
title('RX Sinyali Spectrogramı');

%% --- Sızıntı seviyesi ölçümü ---
[peakVal, peakIdx] = max(RX_dB);
peakFreq = f(peakIdx);

noiseFloorIdx = abs(f - toneOffset) > 200e3; % ton bandının dışındaki bölge
noiseFloor = mean(RX_dB(noiseFloorIdx));

fprintf('\n--- SIZINTI ÖLÇÜM SONUCU ---\n');
fprintf('Tespit edilen tepe frekansı : %.1f kHz\n', peakFreq/1e3);
fprintf('Tepe genliği                : %.1f dB\n', peakVal);
fprintf('Gürültü tabanı (ort.)       : %.1f dB\n', noiseFloor);
fprintf('SNR (yaklaşık)              : %.1f dB\n', peakVal - noiseFloor);
fprintf('-----------------------------\n');

if abs(peakFreq - toneOffset) < 5e3
    fprintf('✓ Ton doğru frekansta tespit edildi. TX/RX full duplex ÇALIŞIYOR.\n');
else
    fprintf('⚠ Beklenen frekansta net bir tepe bulunamadı. Anten bağlantılarını ve gain değerlerini kontrol et.\n');
end
