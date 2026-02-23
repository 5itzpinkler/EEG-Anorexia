% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. НАЛАШТУВАННЯ ---
baseDirectory = 'X:\EEGMAG\ab3';
tableFile = fullfile(baseDirectory, 'PSD_Results_Grouped.csv'); 

% Що малюємо? (Можеш міняти ці параметри!)
targetBand = 'Gamma'; % Варіанти: 'Theta', 'Alpha', 'Beta', 'Gamma'
conditionToPlot = 'Cross'; % Варіанти: 'Slide' (стимул) або 'Cross' (фон)

% --- 2. ПОШУК ШАБЛОНУ ДЛЯ КООРДИНАТ ЕЛЕКТРОДІВ ---
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
epochedDir = fullfile(baseDirectory, 'Data_Epoched');
sampleFile = dir(fullfile(epochedDir, '**\*.set')); 

if isempty(sampleFile)
    error('Не знайдено жодного .set файлу для шаблону координат!');
end
% Завантажуємо тільки структуру (швидко)
EEG = pop_loadset('filename', sampleFile(1).name, 'filepath', sampleFile(1).folder, 'loadmode', 'info');
chanlocs = EEG.chanlocs;
chanLabels = {chanlocs.labels};

% --- 3. ЧИТАННЯ ДАНИХ ТА ФІЛЬТРАЦІЯ ---
fprintf('Читання таблиці PSD...\n');
T = readtable(tableFile);

% Фільтруємо за умовою (Slide або Cross)
idxCondition = strcmpi(T.Condition, conditionToPlot);

% Розділяємо на групи
idxControl = strcmp(T.Group, 'Control') & idxCondition;
idxAnorexia = strcmp(T.Group, 'Anorexia') & idxCondition;

% --- 4. ЗБІР ДАНИХ ДЛЯ МАЛЮВАННЯ ---
controlData = zeros(1, length(chanLabels));
anorexiaData = zeros(1, length(chanLabels));

for c = 1:length(chanLabels)
    colName = sprintf('%s_%s', chanLabels{c}, targetBand);
    
    if ismember(colName, T.Properties.VariableNames)
        controlData(c) = mean(T{idxControl, colName}, 'omitnan');
        anorexiaData(c) = mean(T{idxAnorexia, colName}, 'omitnan');
    else
        warning('Не знайдено колонку: %s', colName);
    end
end

% Рахуємо різницю (Анорексія мінус Контроль)
diffData = anorexiaData - controlData;

% --- 5. ВІЗУАЛІЗАЦІЯ ---
figName = sprintf('PSD Comparison: %s band (%s)', targetBand, conditionToPlot);
figure('Name', figName, 'Position', [100, 300, 1200, 400]);

% Спільні ліміти кольорів для перших двох графіків
colorLimits = [min([controlData, anorexiaData]), max([controlData, anorexiaData])];

% Графік 1: Control
subplot(1,3,1);
topoplot(controlData, chanlocs, 'maplimits', colorLimits, 'electrodes', 'on');
title(sprintf('Control (n=%d епох)', sum(idxControl)));
colorbar;

% Графік 2: Anorexia
subplot(1,3,2);
topoplot(anorexiaData, chanlocs, 'maplimits', colorLimits, 'electrodes', 'on');
title(sprintf('Anorexia (n=%d епох)', sum(idxAnorexia)));
colorbar;

% Графік 3: Різниця (Anorexia - Control)
subplot(1,3,3);
maxDiff = max(abs(diffData));
if maxDiff == 0, maxDiff = 1; end % Запобігання помилці, якщо різниця нульова
topoplot(diffData, chanlocs, 'maplimits', [-maxDiff, maxDiff], 'electrodes', 'on');
title('Difference (Anorexia - Control)');
colorbar;

colormap(parula); 

disp('=== ВІЗУАЛІЗАЦІЯ ГОТОВА ===');