% Шлях, який ти вказав
folderPath = 'X:\EEGMAG\PICS\PSD'; 

% Отримуємо список усіх .fig файлів
figFiles = dir(fullfile(folderPath, '*.fig'));

if isempty(figFiles)
    fprintf('Помилка: У папці %s не знайдено .fig файлів. Перевір шлях!\n', folderPath);
else
    fprintf('Знайдено %d файлів. Починаю конвертацію в PNG...\n', length(figFiles));
    
    for i = 1:length(figFiles)
        currentFile = fullfile(folderPath, figFiles(i).name);
        
        % Відкриваємо фігуру приховано (invisible), щоб не миготіло перед очима
        fig = openfig(currentFile, 'invisible');
        
        % Готуємо ім'я для PNG
        [~, fileName, ~] = fileparts(figFiles(i).name);
        outputName = fullfile(folderPath, [fileName '.png']);
        
        % Зберігаємо з високою роздільною здатністю (300 DPI)
        % Це зробить лінії та текст на топоплотах ідеальними
        exportgraphics(fig, outputName, 'Resolution', 300);
        
        close(fig);
        fprintf('Сконвертовано: %s.png\n', fileName);
    end
    
    disp('=== ПЕРЕМОГА: УСІ КАРТИНКИ ГОТОВІ! ===');
end