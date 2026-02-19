% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. НАЛАШТУВАННЯ ДИРЕКТОРІЙ ТА ПАРАМЕТРІВ ---
baseDirectory = 'X:\EEGMAG\ab3';
inputDirectory = fullfile(baseDirectory, 'Data_Procesed');
outputDirectory = fullfile(baseDirectory, 'Data_Epoched'); % Головна папка для епох

if ~exist(outputDirectory, 'dir')
    mkdir(outputDirectory);
end

% Дозволені теги 
validTags = ["Proective", "New1", "New2", "New3", "New4"]; 

% Тривалість епохи в секундах ПІСЛЯ маркера
epochDuration = 10; 

% --- 2. ЗАПУСК EEGLAB ---
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% --- 3. ПОШУК ФАЙЛІВ ---
setFiles = dir(fullfile(inputDirectory, '*.set'));
if isempty(setFiles)
    error('Не знайдено файлів .set у папці %s!', inputDirectory);
end

% --- 4. ЦИКЛ ОБРОБКИ ---
for j = 1:length(setFiles)
    
    dataName = setFiles(j).name(1:end-4);
    
    % Розбиваємо ім'я (напр. "exp10_New1" -> resp{1}="exp10", resp{2}="New1")
    resp = split(dataName, '_');
    if length(resp) >= 2
        subjectFolder = string(resp{1}); % Назва папки (exp10)
        logName = string(resp{2});
    else
        subjectFolder = "Other";
        logName = ""; 
    end
    
    % Фільтрація за тегами
    if ~ismember(logName, validTags)
        fprintf('Пропускаю (не в validTags): %s\n', dataName);
        continue;
    end
    
    fprintf('\n=== Епохінг: %s ===\n', setFiles(j).name);
    
    % --- СТВОРЕННЯ ПАПКИ ДЛЯ РЕСПОНДЕНТА ---
    subjectOutDir = fullfile(outputDirectory, char(subjectFolder));
    if ~exist(subjectOutDir, 'dir')
        mkdir(subjectOutDir);
    end
    
    % Завантаження файла
    EEG = pop_loadset('filename', setFiles(j).name, 'filepath', inputDirectory);
    
    if isempty(EEG.event)
        warning('У файлі %s немає маркерів! Пропускаю.', dataName);
        continue;
    end
    
    originalEEG = EEG; 
    foundCount = 0;
    crossCounter = 0; 
    
    for e = 1:length(originalEEG.event)
        currentEvent = char(strtrim(string(originalEEG.event(e).type)));
        outLabel = ""; 
        
        % Логіка 1: Якщо це слайд
        if startsWith(currentEvent, 'slide', 'IgnoreCase', true)
            outLabel = strrep(currentEvent, '.png', '');
            foundCount = foundCount + 1;
            
        % Логіка 2: Якщо це хрестик фіксації
        elseif strcmp(currentEvent, 'cross')
            crossCounter = crossCounter + 1;
            outLabel = sprintf('cross_%d', crossCounter); 
            foundCount = foundCount + 1;
        end
        
        % Якщо маркер валідний, перевіряємо чи він уже є, і вирізаємо
        if outLabel ~= ""
            % Формуємо назву файла (напр. "exp10_New1_slide1.set")
            outName = sprintf('%s_%s.set', dataName, outLabel);
            finalFilePath = fullfile(subjectOutDir, outName);
            
            % === РОЗУМНИЙ ПРОПУСК ===
            if exist(finalFilePath, 'file')
                fprintf('  [Пропуск] Епоха вже існує: %s\n', outName);
                continue; % Йдемо до наступного маркера
            end
            % ========================
            
            latencySec = originalEEG.event(e).latency / originalEEG.srate;
            timeRange = [latencySec, latencySec + epochDuration];
            
            if timeRange(2) > originalEEG.xmax
                timeRange(2) = originalEEG.xmax;
            end
            
            try
                chunkEEG = pop_select(originalEEG, 'time', timeRange);
                chunkEEG = pop_saveset(chunkEEG, 'filename', outName, 'filepath', subjectOutDir);
                fprintf('  Збережено епоху: %s\n', outName);
            catch ME
                warning('  Помилка вирізання епохи %s: %s', outName, ME.message);
            end
        end
    end
    
    if foundCount == 0
        fprintf('  У файлі не знайдено жодного маркера (слайду або хрестика).\n');
    end
end

disp('=== ЕПОХІНГ ЗАВЕРШЕНО ===');