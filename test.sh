#!/bin/bash

SCRIPT_UNDER_TEST="./base.sh"  
TEST_DIR_BASE="~/mnt_test_dir"
BACKUP_DIR="$HOME/backup"


fill_dir() {
    local dir=$1
    local n=${2:-100}
    local count_bs_in_one_file=${3:-1}
    mkdir -p "$dir"
    # создаём n файлов по 10МБ * count_bs_in_one_file
    for ((i=1; i<= $n;i++)); do
        dd if=/dev/zero of="$dir/file_$i" bs=10M count=$count_bs_in_one_file status=none
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

echo "===== Подготовка к тестам ====="
mkdir -p "$TEST_DIR_BASE" 1>/dev/null
mkdir -p "$BACKUP_DIR" 1>/dev/null
dd if=/dev/zero of=./VHD.img bs=1M count=1200 > /dev/null 2>&1
mkfs -t ext4 ./VHD.img > /dev/null 2>&1
guestmount -a ./VHD.img -m /dev/sda "$TEST_DIR_BASE" > /dev/null 2>&1

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
fill_dir "$TEST_DIR" 60
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

### ТЕСТ 6: Запуск с export LAB1_MAX_COMPRESSION=0 и одним большим файлом
echo "== Тест 6: запуск с LAB1_MAX_COMPRESSION=0 и одним большим файлом"
export LAB1_MAX_COMPRESSION=0
TEST_DIR="$TEST_DIR_BASE"
fill_dir "$TEST_DIR" 1 100
$SCRIPT_UNDER_TEST "$TEST_DIR" 15 1>/dev/null
echo "Код выхода: $?"
check_backup
cleanup

echo "===== Тесты завершены ====="
guestunmount "$TEST_DIR_BASE"