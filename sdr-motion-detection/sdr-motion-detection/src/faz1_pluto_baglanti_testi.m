%% FAZ 1 - Pluto SDR Bağlantı ve Donanım Doğrulama
% Amaç: Pluto'nun MATLAB tarafından görüldüğünü doğrulamak,
% temel radio bilgilerini (seri no, firmware) ekrana yazdırmak.
%
% Gereksinimler:
%   - Communications Toolbox
%   - Communications Toolbox Support Package for ADALM-PLUTO Radio
%     (yoksa: Add-On Explorer'dan "ADALM-PLUTO" ara ve kur)

clear; clc;

fprintf('Pluto radyoları taranıyor...\n');
radioFound = findPlutoRadio();

if isempty(radioFound)
    error(['Pluto bulunamadı. Kontrol et: ', ...
        '1) USB kablosu takılı mı, ', ...
        '2) sürücüler kurulu mu, ', ...
        '3) Support Package kurulu mu.']);
end

fprintf('%d adet Pluto bulundu:\n', numel(radioFound));
for k = 1:numel(radioFound)
    fprintf('  [%d] SerialNum: %s | RadioID: %s\n', ...
        k, radioFound(k).SerialNum, radioFound(k).RadioID);
end

% NOT: sdrinfo() fonksiyonu burada gereksiz - findPlutoRadio() zaten
% ihtiyacımız olan RadioID ve SerialNum bilgisini yukarıda verdi.
% sdrinfo, ayrı bir DeviceAddress formatı beklediği için (IP veya
% integer) burada hataya sebep oluyordu, o yüzden kaldırıldı.

fprintf('\nBağlantı testi başarılı. Faz 2''ye geçebilirsin.\n');
