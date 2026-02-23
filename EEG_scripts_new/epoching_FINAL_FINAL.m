% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. ШЛЯХИ ТА НАЛАШТУВАННЯ ---
baseDirectory = 'X:\EEGMAG\ab3';
inputDirectory = fullfile(baseDirectory, 'Data_Procesed');
outputDirectory = fullfile(baseDirectory, 'Data_Epoched'); 
tableFile = fullfile(baseDirectory, 'Subjects.xlsx'); % Твоя таблиця груп

if ~exist(outputDirectory, 'dir'), mkdir(outputDirectory); end

% Точні тривалості епох з твого дизайну!
epochDurSlide = 4.03; 
epochDurCross = 1.03; 

% Дозволені теги
validTags = ["Proective", "New1", "New2", "New3", "New4"]; 

% --- 2. ЗАПУСК EEGLAB ТА ЧИТАННЯ ГРУП ---
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

opts = detectImportOptions(tableFile);
groupsTable = readtable(tableFile, opts);

% Створюємо головні папки
anorexiaDir = fullfile(outputDirectory, 'Anorexia');
controlDir = fullfile(outputDirectory, 'Control');
if ~exist(anorexiaDir, 'dir'), mkdir(anorexiaDir); end
if ~exist(controlDir, 'dir'), mkdir(controlDir); end

% --- 3. ПОШУК ФАЙЛІВ ---
setFiles = dir(fullfile(inputDirectory, '*.set'));
if isempty(setFiles)
    error('Не знайдено файлів .set у папці %s!', inputDirectory);
end

% --- 4. ЦИКЛ ОБРОБКИ ---
for j = 1:length(setFiles)
    dataName = setFiles(j).name(1:end-4);
    
    % Розбиваємо ім'я
    resp = split(dataName, '_');
    if length(resp) >= 2
        subjectFolder = string(resp{1}); 
        logName = string(resp{2});
    else
        continue;
    end
    
    if ~ismember(logName, validTags), continue; end
    
    % Визначаємо групу
    expNumStr = regexp(char(subjectFolder), '\d+', 'match');
    if isempty(expNumStr), continue; end
    expNum = str2double(expNumStr{1});
    
    if expNum <= height(groupsTable)
        rawGroup = char(groupsTable{expNum, 2}); 
        if contains(lower(rawGroup), 'an')
            subjectOutDir = fullfile(anorexiaDir, char(subjectFolder));
        else
            subjectOutDir = fullfile(controlDir, char(subjectFolder));
        end
    else
        subjectOutDir = fullfile(outputDirectory, 'Unknown', char(subjectFolder));
    end
    
    if ~exist(subjectOutDir, 'dir'), mkdir(subjectOutDir); end
    
    fprintf('\n=== Епохінг: %s ===\n', setFiles(j).name);
    EEG = pop_loadset('filename', setFiles(j).name, 'filepath', inputDirectory);
    
    if isempty(EEG.event), continue; end
    
    % --- АВТОМАТИЧНА ОЧИСТКА ВІД ОЧЕЙ ТА М'ЯЗІВ (ICLabel) ---
    % Якщо у файлі є розраховані ICA-ваги, ми їх чистимо
    if ~isempty(EEG.icaweights)
        fprintf('  > Запуск ICLabel для видалення артефактів...\n');
        EEG = iclabel(EEG); % Нейромережа аналізує компоненти
        % Шукаємо компоненти, які на 80% і більше є очима або м'язами
        bad_components = find(EEG.etc.ic_classification.ICLabel.classifications(:,2) >= 0.8 | ... % М'язи
                              EEG.etc.ic_classification.ICLabel.classifications(:,3) >= 0.8);     % Очі
        if ~isempty(bad_components)
            fprintf('  > Видалено поганих компонентів: %d шт.\n', length(bad_components));
            EEG = pop_subcomp(EEG, bad_components, 0); % Видаляємо їх з сигналу!
        else
            fprintf('  > Поганих компонентів не знайдено.\n');
        end
    end
    
    originalEEG = EEG; 
    crossCounter = 0; 
    
    for e = 1:length(originalEEG.event)
        currentEvent = char(strtrim(string(originalEEG.event(e).type)));
        outLabel = ""; 
        currentDuration = 0;
        
        if startsWith(currentEvent, 'slide', 'IgnoreCase', true)
            outLabel = strrep(currentEvent, '.png', '');
            currentDuration = epochDurSlide; % 4 секунди
        elseif strcmp(currentEvent, 'cross')
            crossCounter = crossCounter + 1;
            outLabel = sprintf('cross_%d', crossCounter); 
            currentDuration = epochDurCross; % 1 секунда
        end
        
        if outLabel ~= ""
            outName = sprintf('%s_%s.set', dataName, outLabel);
            finalFilePath = fullfile(subjectOutDir, outName);
            
            if exist(finalFilePath, 'file')
                fprintf('  [Пропуск] Епоха вже існує: %s\n', outName);
                continue; 
            end
            
            latencySec = originalEEG.event(e).latency / originalEEG.srate;
            timeRange = [latencySec, latencySec + currentDuration];
            
            if timeRange(2) > originalEEG.xmax
                timeRange(2) = originalEEG.xmax;
            end
            
            try
                chunkEEG = pop_select(originalEEG, 'time', timeRange);
                chunkEEG = pop_saveset(chunkEEG, 'filename', outName, 'filepath', subjectOutDir);
                fprintf('  Збережено епоху: %s (Довжина: %.1f с)\n', outName, currentDuration);
            catch ME
                warning('  Помилка вирізання епохи %s: %s', outName, ME.message);
            end
        end
    end
end

disp('=== ЧИСТИЙ ЕПОХІНГ ЗАВЕРШЕНО ===');