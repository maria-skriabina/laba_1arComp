#!/bin/bash

SCRIPT_UNDER_TEST="./base.sh"  
TEST_DIR_BASE="/mnt/VHD/"
BACKUP_DIR="$HOME/backup"


fill_dir() {
    local dir=$1
    local n=${2:-100}
    mkdir -p "$dir"
    # создаём n файлов по 100МБ
    for ((i=1; i<= $n;i++)); do
        dd if=/dev/zero of="$dir/file_$i" bs=10M count=1 status=none
    done
}

# Очистка после теста
cleanup() {
    find "$TEST_DIR_BASE" -type f -delete
    rm   "$BACKUP_DIR/oldest_files.tar.gz" 2>/dev/null
    rm   "$BACKUP_DIR/oldest_files.tar.lzma" 2>/dev/null
}

check_backup() {
    if [[ -f "$BACKUP_DIR/oldest_files.tar.gz" || -f "$BACKUP_DIR/oldest_files.tar.lzma" ]]; then
        echo "Резервная копия создана успешно."
    else
        echo "Резервная копия не найдена!"
    fi
}
echo "===== Запуск тестов ====="
cleanup

### ТЕСТ 1: Запуск без аргументов
echo "== Тест 1: запуск без аргументов (ожидаем ошибку)"
TEST_DIR="$TEST_DIR_BASE"
fill_dir "$TEST_DIR"
$SCRIPT_UNDER_TEST 1>/dev/null
echo "Код выхода: $?"
cleanup

### ТЕСТ 2: Некорректная директория
echo "== Тест 2: запуск с несуществующей директорией (ожидаем ошибку)"
$SCRIPT_UNDER_TEST /fake/path 1>/dev/null
echo "Код выхода: $?"

### ТЕСТ 3: Корректный запуск с директорией
echo "== Тест 3: запуск с заполненной директорией, дефолтный процент (70%)"
TEST_DIR="$TEST_DIR_BASE"
fill_dir "$TEST_DIR" 6
$SCRIPT_UNDER_TEST "$TEST_DIR" 1>/dev/null
echo "Код выхода: $?"
cleanup

### ТЕСТ 4: Корректный запуск с указанием процента заполненности
echo "== Тест 4: запуск с заполненной директорией, порог 15%"
TEST_DIR="$TEST_DIR_BASE"
fill_dir "$TEST_DIR"
$SCRIPT_UNDER_TEST "$TEST_DIR" 15 1>/dev/null
echo "Код выхода: $?"
check_backup
cleanup

### ТЕСТ 5: Запуск с export LAB1_MAX_COMPRESSION=1
echo "== Тест 5: запуск с LAB1_MAX_COMPRESSION=1"
export LAB1_MAX_COMPRESSION=1
TEST_DIR="$TEST_DIR_BASE"
fill_dir "$TEST_DIR"
$SCRIPT_UNDER_TEST "$TEST_DIR" 15 1>/dev/null
echo "Код выхода: $?"
check_backup
cleanup

### ТЕСТ 6: Запуск с export LAB1_MAX_COMPRESSION=0
echo "== Тест 6: запуск с LAB1_MAX_COMPRESSION=0"
export LAB1_MAX_COMPRESSION=0
TEST_DIR="$TEST_DIR_BASE"
fill_dir "$TEST_DIR"
$SCRIPT_UNDER_TEST "$TEST_DIR" 15 1>/dev/null
echo "Код выхода: $?"
check_backup
cleanup

echo "===== Тесты завершены ====="