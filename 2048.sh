#!/bin/bash

declare -ia border    # граница, в которой хранится игровой поток
declare -i score=0   # количество ячеек, которые можно объединить, варьируется
declare -i omitted_signal # всегда выполнять только одну операцию в одном поле за раз
declare -i moves     # сохранить количество возможных игроков, чтобы определить, проиграл ли игрок игру
declare -i pieces    # для хранения количества фигур на экране
declare -i celpoint_score=2048 #если игрок достигает этого значения, он выигрывает

#назначить цвета разным числам
declare -a symbol_color #объявление цвета границы
symbol_color[2]=35        # фиолетовый
symbol_color[4]=36        # голубой
symbol_color[8]=34         # зеленый
symbol_color[16]=32         # лаймовый
symbol_color[32]=33         # жёлтый 
symbol_color[64]="31m\033[7"      # красный
symbol_color[128]="36m\033[7"       # небесный голубой
symbol_color[256]="34m\033[7"       # голубой
symbol_color[512]="32m\033[7"       # зеленый
symbol_color[1024]="33m\033[7"        # жёлтый

trap "game_over 0 1" INT
#указать цвет последних добавленных цифр в красный
function border_paint {
  clear #терминал удаляет предыдущую границу и всегда показывает только текущую
  printf "(Move by pressing: W,A,S,D) (To exit press: CTRL+C) \n"
  printf "Pieces=$pieces Need=$celpoint_score Score=$score\n"
  printf "\n"
  printf 'O------¤------¤------¤------O\n' #рисование первой линии
  
  for l in {0..3}; do #number of rows 0-3 to 4pcs
    printf '|'
    for m in {0..3}; do #number of columns 0-3 to 4pcs
      if let ${border[l*4+m]}; then
        if let '(last_added==(l*4+m))|(first_round==(l*4+m))'; then
          printf '\033[1m\033[31m %4d \033[0m|' ${border[l*4+m]} # вставить ячейку с недавно добавленным значением (КРАСНЫЙ)
        else
          printf "\033[1m\033[${symbol_color[${border[l*4+m]}]}m %4d\033[0m |" ${border[l*4+m]} # ячейка с ранее добавленным значением, нарисовать с symbol_color согласно назначенному ранее
        fi
      else
        printf '      |' # когда есть пустая ячейка
      fi
    done
    let l==3 || {
      printf '\n|------' #фронт
      for l in {seq 1 3}; do #использование оператора seq l == от 3 до 3, иначе 1
        printf '¤------' 
      done
      printf '|\n'
    }
  done
  printf '\nO------¤------¤------¤------O\n' # нарисовать последнюю линию границы
}

# Генерация клеток на гранях
# Вход:
# $ border - исходное состояние границы
# $ piece - исходное количество штук
# выход:
# $ border - состояние после функций
# $pieces -новое количество
function generate_pieces { # функция для генерации новых значений 2s
  while true; do
    let poz=RANDOM%all_field # случайное положение ячейки для новых значений
    let border[$poz] || {
      let value=RANDOM%10?2:4 # 2 или 4 могут быть новым значением
      border[$poz]=$value
      last_added=$poz 
      break;
    }
  done
  let pieces++ # увеличим количество клеток с цифрами на 1
}

# Слияние цифр
# Вход:
# $ 1 - слияние по позиции, по горизонтали в заданной строке, по вертикали в столбце
# $ 2 - если объединится в один кусок, он сохранит результат, если он будет перемещен или объединен
# $ 3 - оригинальный кусок, после перемещения или слияния он остается пустым
# $ 4 - направление объединения, может быть «вверх», «вниз», «влево» или «вправо»
# 5 - обновлять количество плавных движений, только если что-то пошло не так - не объединять ячейки
# $ border - исходное состояние игровой границы
# выходов:
# $ modulate - указывает, что граница изменилась в этом месте
# $ omarded_signal - если деталь, в которую вы хотите вставить, больше не может быть изменена, указать это
# $ border - новая игровая граница
function pieces_length {
  case $4 in
    "up")
      let "first=$2*4+$1"
      let "second=($2+$3)*4+$1"
      ;;
    "down")
      let "first=(index_max-$2)*4+$1"
      let "second=(index_max-$2-$3)*4+$1"
      ;;
    "left")
      let "first=$1*4+$2"
      let "second=$1*4+($2+$3)"
      ;;
    "right")
      let "first=$1*4+(index_max-$2)"
      let "second=$1*4+(index_max-$2-$3)"
      ;;
  esac
  let ${border[$first]} || { #first border, not the second
    let ${border[$second]} && {
      if test -z $5; then
        border[$first]=${border[$second]}
        let border[$second]=0
        let modulate=1
      else
        let moves++
      fi
      return
    }
    return
  }
  let ${border[$second]} && let omitted_signal=1 # second border, can do not be the first.
  let "${border[$first]}==${border[second]}" && { 
    if test -z $5; then
      let border[$first]*=2
      let "border[$first]==$celpoint_score" && game_over 1
      let border[$second]=0
      let pieces-=1
      let modulate=1
      let score+=${border[$first]}
    else
      let moves++
    fi
  }
}
# объединение первой и второй границ
function movement_drive {
  for i in $(seq 0 $index_max); do
    for j in $(seq 0 $index_max); do
      omitted_signal=0
      let max_increase=index_max-j
      for k in $(seq 1 $max_increase); do
        let omitted_signal && break
        pieces_length $i $j $k $1 $2
      done 
    done
  done
}

function moving_controls {
  let moves=0
}

function user_input {
  let modulate=0
  read -d '' -sn 1
  test "$REPLY" = "$'\e'" && {
    read -d '' -sn 1 -t1
    test "$REPLY" = "[" && {
      read -d '' -sn 1 -t1
      case $REPLY in
        up) movement_drive up;;
        down) movement_drive down;;
        right) movement_drive right;;
        left) movement_drive left;;
      esac
    }
  } || {
    case $REPLY in #если нажата одна из кнопок
      w) movement_drive up;;
      s) movement_drive down;;
      d) movement_drive right;;
      a) movement_drive left;;
    esac
  }
}

function game_over {
  border_paint
  printf "Reached score: $score\n"

  let $1 && {
    printf "Congratulations, completed point: $celpoint_score\n"
    exit 0
  }
  printf "\nYou lost because all the places were full and you didn't reach enough points $celpoint_score\n"
  exit 0
}

# rudimentary border
let all_field=16
let index_max=3
for i in $(seq 0 $all_field); do border[$i]="0"; done # rudimentary border replenishment
let pieces=0
generate_pieces
first_round=$last_added
generate_pieces

while true; do # пока условия верны и вы не проиграли делаем цикл
  border_paint
  user_input
  let modulate && generate_pieces
  first_round=-1
  let pieces==all_field && {
   moving_controls
   let moves==0 && game_over 0 # если проигрыш прерываем цикл и выдаём нужные значения
  }
done