% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. ШЛЯХИ ТА НАЛАШТУВАННЯ ---
baseDirectory = 'X:\EEGMAG\ab3';
inputDirectory = fullfile(baseDirectory, 'Data_Epoched');
outputFile = fullfile(baseDirectory, 'PSD_Results_Grouped.csv'); 

% Налаштування частотних діапазонів
bandNames = {'Theta', 'Alpha', 'Beta', 'Gamma'};
bandLimits = [4 8; 8 13; 13 30; 30 45]; 
numBands = length(bandNames);

% --- 2. ЗАПУСК EEGLAB ---
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

groups = {'Anorexia', 'Control'};
allResults = {}; % Оголошуємо як cell array, щоб уникнути будь-яких помилок
colNames = {'Subject', 'Group', 'Condition', 'Epoch'};
headersGenerated = false;

fprintf('Починаємо розрахунок PSD на чистих епохах...\n');

% --- 3. ЦИКЛ ОБРОБКИ ---
for g = 1:length(groups)
    groupName = groups{g};
    groupDir = fullfile(inputDirectory, groupName);
    
    if ~exist(groupDir, 'dir')
        continue;
    end
    
    % Шукаємо всі папки респондентів (exp1, exp10...) всередині групи
    subjFolders = dir(fullfile(groupDir, 'exp*'));
    subjFolders = subjFolders([subjFolders.isdir]);
    
    for s = 1:length(subjFolders)
        subjName = subjFolders(s).name;
        subjDir = fullfile(groupDir, subjName);
        
        setFiles = dir(fullfile(subjDir, '*.set'));
        if isempty(setFiles)
            continue;
        end
        
        fprintf('Обробка: %s (Група: %s)\n', subjName, groupName);
        
        for f = 1:length(setFiles)
            fileName = setFiles(f).name;
            EEG = pop_loadset('filename', fileName, 'filepath', subjDir);
            
            % Визначаємо назву епохи
            nameParts = split(fileName(1:end-4), '_');
            if length(nameParts) >= 3
                epochType = strjoin(nameParts(3:end), '_'); 
            else
                epochType = fileName(1:end-4);
            end
            
            % Додаємо мітку умови
            if contains(epochType, 'cross', 'IgnoreCase', true)
                conditionLabel = 'Cross';
            else
                conditionLabel = 'Slide';
            end
            
            % Розрахунок PSD (без малювання графіків у процесі)
            [spectra, freqs] = spectopo(EEG.data, 0, EEG.srate, 'plot', 'off', 'quiet', 'on');
            absolutePower = 10.^(spectra/10); 
            
            rowValues = {subjName, groupName, conditionLabel, epochType};
            
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
end

% --- 4. ЗБЕРЕЖЕННЯ В ТАБЛИЦЮ ---
if isempty(allResults)
    error('Не знайдено жодного файлу для обробки! Перевір, чи є файли .set у папках Anorexia та Control.');
else
    fprintf('\nФормування таблиці та збереження у файл: %s\n', outputFile);
    resultsTable = cell2table(allResults, 'VariableNames', colNames);
    writetable(resultsTable, outputFile);
    disp('=== PSD АНАЛІЗ ЗАВЕРШЕНО ===');
end