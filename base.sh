#!/bin/bash

if [[ $# -eq 0 ]]; then
    echo "Укажите путь до директории и (опционально) процент заполненности"
    exit 1
fi

if [[ $# -gt 2 ]]; then
    echo "Слишком много аргументов"
    exit 1
fi

if [[ ! -d $1 ]]; then
    echo "Указанный путь не является директорией"
    exit 1
fi

if [[ ! -z $2 && ( (! $2 =~ ^[0-9]+$) ||  $2 -lt 0 || $2 -gt 100 ) ]]; then
    echo "Неверно указан процент заполненности, должно быть число от 0 до 100"
    exit 1
fi

dir_path=$1

persent=${2:-70}

mapfile -t files < <(find "$dir_path" -type f -printf '%T@ %s %p\n' 2>/dev/null | sort -n)

fs_total=$(df --output=size -k "$dir_path" | tail -1)
fs_used=$(df --output=used -k "$dir_path" | tail -1)


target_used_kb=$(( fs_total * persent / 100 ))
echo "Нужно освободить место, чтобы занято было не более $target_used_kb КБ"
to_free_kb=$(( fs_used - target_used_kb ))


if [[ $to_free_kb -le 0 ]]; then
    exit 0
fi
echo "Нужно освободить $to_free_kb КБ"

sum=0
N=0
files_to_delete=()
for file_info in "${files[@]}"; do
    size=$(echo "$file_info" | awk '{print $2}' )
    relpath=$(echo "$file_info" | awk '{print $3}')
    files_to_delete+=("$relpath")
    sum=$((sum + size))
    N=$((N + 1))
    if [[ $sum -ge $to_free_kb*1024 ]]; then
        break
    fi
done
echo $files_to_delete
echo "Всего файлов для удаления: $N, общий размер: $((sum/1024)) КБ"

if [[ $N -eq 0 ]]; then
    echo "Нет файлов для удаления или недостаточно файлов для освобождения места."
    exit 1
fi

backup_dir="$HOME/backup"


if [[ "$LAB1_MAX_COMPRESSION" == "1" ]]; then
    tar_ext="tar.lzma"
    tar_opts="--lzma"
else
    tar_ext="tar.gz"
    tar_opts="-z"
fi


tar -c ${tar_opts} -f "$backup_dir/oldest_files.$tar_ext" -C "$dir_path" "${files_to_delete[@]}" 2>/dev/null


for file in "${files_to_delete[@]}"; do
    echo "Удаляем файл $file"
    rm -f "$file"
done

exit 0