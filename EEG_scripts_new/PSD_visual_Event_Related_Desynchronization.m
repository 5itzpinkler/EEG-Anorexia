% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. НАЛАШТУВАННЯ ---
baseDirectory = 'X:\EEGMAG\ab3';
tableFile = fullfile(baseDirectory, 'PSD_Results_Grouped.csv'); 

% Що малюємо?
targetBand = 'Gamma'; % Змінюй на 'Theta', 'Beta', 'Gamma' 'Alpha'

% --- 2. ПОШУК ШАБЛОНУ ДЛЯ КООРДИНАТ ЕЛЕКТРОДІВ ---
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
epochedDir = fullfile(baseDirectory, 'Data_Epoched');
sampleFile = dir(fullfile(epochedDir, '**\*.set')); 

if isempty(sampleFile)
    error('Не знайдено жодного .set файлу для шаблону координат!');
end
EEG = pop_loadset('filename', sampleFile(1).name, 'filepath', sampleFile(1).folder, 'loadmode', 'info');
chanlocs = EEG.chanlocs;
chanLabels = {chanlocs.labels};

% --- 3. ЧИТАННЯ ДАНИХ ТА ФІЛЬТРАЦІЯ ---
fprintf('Читання таблиці PSD...\n');
T = readtable(tableFile);

% Витягуємо індекси для кожної групи і умови
idxControlCross = strcmp(T.Group, 'Control') & strcmpi(T.Condition, 'Cross');
idxControlSlide = strcmp(T.Group, 'Control') & strcmpi(T.Condition, 'Slide');

idxAnorexiaCross = strcmp(T.Group, 'Anorexia') & strcmpi(T.Condition, 'Cross');
idxAnorexiaSlide = strcmp(T.Group, 'Anorexia') & strcmpi(T.Condition, 'Slide');

% --- 4. РОЗРАХУНОК РЕАКТИВНОСТІ (Слайд мінус Хрестик) ---
reactControl = zeros(1, length(chanLabels));
reactAnorexia = zeros(1, length(chanLabels));

for c = 1:length(chanLabels)
    colName = sprintf('%s_%s', chanLabels{c}, targetBand);
    
    if ismember(colName, T.Properties.VariableNames)
        % Середнє для кожної підгрупи
        mControlCross = mean(T{idxControlCross, colName}, 'omitnan');
        mControlSlide = mean(T{idxControlSlide, colName}, 'omitnan');
        
        mAnorexiaCross = mean(T{idxAnorexiaCross, colName}, 'omitnan');
        mAnorexiaSlide = mean(T{idxAnorexiaSlide, colName}, 'omitnan');
        
        % Реактивність: Слайд - Хрестик
        reactControl(c) = mControlSlide - mControlCross;
        reactAnorexia(c) = mAnorexiaSlide - mAnorexiaCross;
    end
end

% Різниця між групами у їхній реакції (Взаємодія)
diffReaction = reactAnorexia - reactControl;

% --- 5. ВІЗУАЛІЗАЦІЯ ---
figName = sprintf('Reactivity (Slide minus Cross): %s band', targetBand);
figure('Name', figName, 'Position', [100, 300, 1200, 400]);

% Ліміти для реактивності робимо симетричними (щоб нуль був зеленим)
maxAbsReact = max(abs([reactControl, reactAnorexia]));
if maxAbsReact == 0, maxAbsReact = 1; end
colorLimits = [-maxAbsReact, maxAbsReact];

% Графік 1: Реакція Контролю
subplot(1,3,1);
topoplot(reactControl, chanlocs, 'maplimits', colorLimits, 'electrodes', 'on');
title('Control Reactivity (Slide-Cross)');
colorbar;

% Графік 2: Реакція Анорексії
subplot(1,3,2);
topoplot(reactAnorexia, chanlocs, 'maplimits', colorLimits, 'electrodes', 'on');
title('Anorexia Reactivity (Slide-Cross)');
colorbar;

% Графік 3: Різниця в реакції між групами
subplot(1,3,3);
maxDiff = max(abs(diffReaction));
if maxDiff == 0, maxDiff = 1; end
topoplot(diffReaction, chanlocs, 'maplimits', [-maxDiff, maxDiff], 'electrodes', 'on');
title('Group Diff (Anorexia - Control)');
colorbar;

colormap(parula); % Можна замінити на 'jet' для яскравіших кольорів

disp('=== КАРТИ РЕАКТИВНОСТІ ГОТОВІ ===');