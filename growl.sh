#!/bin/bash

# Работа с Growl на bash. Евгений Степанищев http://bolknote.ru/ 2012
# Growl communication in Bash. Copyright by Evgeny Stepanischev http://bolknote.ru/ 2012

APPLICATION="My Shell Script"
NOTIFYNAME="Shell Message"
MESSAGE="Hi all!"

# Получаем наш IP 
function _GetMyIP {
    local route=`/sbin/route -n get default 2>&-`

    if [ -z "$route" ]; then
        # Либо, первый попавшийся, если нет IP по-умолчанию
        /sbin/ifconfig |
            /usr/bin/awk '/^[\t ]*inet/ {print $2}' |
            (/usr/bin/egrep -v '^(127\.|::1)' || echo 127.0.0.1) |
            /usr/bin/head -n1

    else
        # Либо IP по-умолчанию в системе, если он назначен
        echo "$route" |
            /usr/bin/egrep -oi 'interface: [^ ]+' |
            /usr/bin/cut -c12- |
            /usr/bin/xargs /usr/sbin/ipconfig getifaddr
    fi
}

# Отсылка сообщение в growl через telnet при помощи expect
# Возвращает «-OK» в случае успеха
function _GrowlSend {
    local ip="$1"
    local port="$2"

    (
        echo "spawn -noecho /usr/bin/telnet -N8EL $ip $port"
        echo set timeout 1
        echo expect_after timeout exit
        echo 'expect "Escape" {'

        while read -re; do
           echo "send -- \"$REPLY\\n\""
        done

        echo 'send "\n"'
        echo expect '"Response-Action"'
        echo '}'
    ) |
        /usr/bin/expect |
        /usr/bin/awk '/^GNTP\/1.0 -(OK|ERROR)/{print $2}'
}

# Посылаем нотификацию
# параметры:
#  IP на котором «слушает» Growl (если пустой, используется локальный)
#  порт на котором «слушает» Growl (если пустой, используется 23053)
#  текст сообщения
# пример:
#  GlowSendNotify "" "" 'Привет всем!'
function GrowlSendNotify {
    local ip="$1"
    [ -z "$ip" ] && ip=$(_GetMyIP)

    local -i port="$2"
    [ $port -gt 0 ] || port=23053

    local text="$3"

    res=`_GrowlSend "$ip" $port <<NOTIFY
GNTP/1.0 NOTIFY NONE
Application-Name: $APPLICATION
Notification-Name: $NOTIFYNAME
Notification-Title: $text
NOTIFY`

    [ "$res" == "-OK" ] && return 0 || return 1
}

# Регистрируем своё приложение
# параметры:
#  IP на котором «слушает» Growl (если пустой, используется локальный)
#  порт на котором «слушает» Growl (если пустой, используется 23053)
# пример:
#  GlowSendRegister
function GrowlSendRegister {
    local ip="$1"
    [ -z "$ip" ] && ip=$(_GetMyIP)

    local -i port="$2"
    [ $port -gt 0 ] || port=23053

    local text="$3"

    res=`_GrowlSend "$ip" $port <<REGISTER
GNTP/1.0 REGISTER NONE
Application-Name: $APPLICATION
Notifications-Count: 1
Notification-Enabled: True 

Notification-Name: $NOTIFYNAME
REGISTER`

    [ "$res" == "-OK" ] && return 0 || return 1
}


# Пробуем отослать сообщение
cmd='GrowlSendNotify "" "" "'"$MESSAGE"'"'

eval $cmd || (
    GrowlSendRegister && eval $cmd
)