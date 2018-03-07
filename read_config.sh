#!/usr/bin/env bash
#set -x


maskAllButLastChars()
{
  printf "%-$(( ${#1} -$2 ))s${1: -$2}\n" " "|sed -e 's/ /*/g'
}


newline_at_eof()
{
  if [ -z $( tail -c -1 "$1") ]
  then
#      echo "Newline at end of file!"
      return 0
  else
#      echo "No newline at end of file!"
      return 1
  fi
  return 0
}

if ! newline_at_eof $1
then
#  echo Need it
   echo "" >> $1
fi

while IFS='= ' read var val
do
    if [[ $var == \[*] ]]
    then
        section=$var
    elif [[ $val ]]
    then
#        echo  "$var$section=$val"
        declare "$var$section=$val"
    fi
done < $1
