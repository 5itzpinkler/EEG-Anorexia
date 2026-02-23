% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. ШЛЯХИ ТА НАЛАШТУВАННЯ ---
baseDirectory = 'X:\EEGMAG\ab3';
inputDirectory = fullfile(baseDirectory, 'Data_Epoched');
outputFile = fullfile(baseDirectory, 'PSD_Results_Grouped.csv'); 

% Файл з групами (той самий Досліджувані, збережений як Subjects.csv)
tableFile = fullfile(baseDirectory, 'Subjects.xlsx'); 

% Налаштування частотних діапазонів
bandNames = {'Theta', 'Alpha', 'Beta', 'Gamma'};
bandLimits = [4 8; 8 13; 13 30; 30 45]; 
numBands = length(bandNames);

% --- 2. ЗАПУСК EEGLAB ТА ЧИТАННЯ ГРУП ---
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Читаємо таблицю груп (очікуємо, що колонка 2 - це назва групи)
opts = detectImportOptions(tableFile);
groupsTable = readtable(tableFile, opts);

% Створюємо головні папки для Brainstorm
anorexiaDir = fullfile(inputDirectory, 'Anorexia');
controlDir = fullfile(inputDirectory, 'Control');
if ~exist(anorexiaDir, 'dir'), mkdir(anorexiaDir); end
if ~exist(controlDir, 'dir'), mkdir(controlDir); end

% Отримуємо список папок респондентів (exp1, exp10...)
subjFolders = dir(fullfile(inputDirectory, 'exp*'));
subjFolders = subjFolders([subjFolders.isdir]);

allResults = [];
colNames = {'Subject', 'Group', 'Epoch'};
headersGenerated = false;

fprintf('Починаємо розподіл по групах та розрахунок PSD...\n');

% --- 3. ЦИКЛ ОБРОБКИ ---
for s = 1:length(subjFolders)
    subjName = subjFolders(s).name;
    oldSubjDir = fullfile(inputDirectory, subjName);
    
    % Витягуємо номер (наприклад, з "exp10" дістаємо число 10)
    expNumStr = regexp(subjName, '\d+', 'match');
    if isempty(expNumStr)
        continue;
    end
    expNum = str2double(expNumStr{1});
    
    % Визначаємо групу за таблицею (номер рядка = номер exp)
    if expNum <= height(groupsTable)
        rawGroup = char(groupsTable{expNum, 2}); 
        if contains(lower(rawGroup), 'an')
            groupName = 'Anorexia';
            newSubjDir = fullfile(anorexiaDir, subjName);
        else
            groupName = 'Control';
            newSubjDir = fullfile(controlDir, subjName);
        end
    else
        groupName = 'Unknown';
        newSubjDir = oldSubjDir; 
    end
    
    % --- ПІДГОТОВКА ДЛЯ BRAINSTORM (Переміщення папки) ---
    if ~strcmp(oldSubjDir, newSubjDir)
        if ~exist(newSubjDir, 'dir')
            movefile(oldSubjDir, newSubjDir);
        end
    end
    
    % Шукаємо епохи вже в новій директорії
    setFiles = dir(fullfile(newSubjDir, '*.set'));
    if isempty(setFiles)
        continue;
    end
    
    fprintf('Обробка респондента: %s (Група: %s)\n', subjName, groupName);
    
    for f = 1:length(setFiles)
        fileName = setFiles(f).name;
        EEG = pop_loadset('filename', fileName, 'filepath', newSubjDir);
        
        % Назва епохи
        nameParts = split(fileName(1:end-4), '_');
        if length(nameParts) >= 3
            epochType = strjoin(nameParts(3:end), '_'); 
        else
            epochType = fileName(1:end-4);
        end
        
        % Розрахунок PSD
        [spectra, freqs] = spectopo(EEG.data, 0, EEG.srate, 'plot', 'off', 'quiet', 'on');
        absolutePower = 10.^(spectra/10);
        
        rowValues = {subjName, groupName, epochType};
        
        % Проходимось по кожному каналу
        for c = 1:EEG.nbchan
            chanLabel = EEG.chanlocs(c).labels;
            for b = 1:numBands
                idx = find(freqs >= bandLimits(b,1) & freqs <= bandLimits(b,2));
                meanPower = mean(absolutePower(c, idx));
                rowValues{end+1} = meanPower;
                
                if ~headersGenerated
                    colNames{end+1} = sprintf('%s_%s', chanLabel, bandNames{b});
                end
            end
        end
        headersGenerated = true;
        allResults = [allResults; rowValues];
    end
end

% --- 4. ЗБЕРЕЖЕННЯ В ТАБЛИЦЮ ---
fprintf('\nФормування таблиці та збереження у файл: %s\n', outputFile);
resultsTable = cell2table(allResults, 'VariableNames', colNames);
writetable(resultsTable, outputFile);

disp('=== PSD ТА РОЗПОДІЛ ДЛЯ BRAINSTORM ЗАВЕРШЕНО ===');