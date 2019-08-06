#!/bin/bash
#------------------------------------------------------------------
# Autor	:	Gabriel Portes
# Nome	:	restore_backup.sh
# Data	:	03/08/2019
#------------------------------------------------------------------

declare -r TRUE=0
declare -r FALSE=1
declare -g LICENCA=''
declare -g FILE_PATH=''
declare -g FILE_PATH_APP=''
declare -g FILE_PATH_CLOUD=''

function menu
{
    clear
    echo -e ""
    echo -e "|----------------------------------------------------|"
    echo -e "|              Restaurar Backup V 1.0                |"
    echo -e "|----------------------------------------------------|"
    echo -e ""
    echo "[ 1 ] Somente apps"
    echo "[ 2 ] Somente cloud"
    echo "[ 3 ] Ambos"
    echo "[ 0 ] Sair"
    echo
    echo -n "Digite a opcao desejada: "
    read OPCAO
    
    if [[ "$OPCAO" = "1" || "$OPCAO" = "2" || "$OPCAO" = "3" ]]
    then
        clear
        echo -n "Digite o nome da licenca: "
        read LICENCA
    fi

    case $OPCAO in
        1) only_app ;;
        2) only_cloud ;;
        3) both_bases ;;
        0) clear; echo -e "SAINDO DO SCRIPT..." ; sleep 2; clear; exit ;;
        *) echo -e "Opc�o desconhecida." ; sleep 2; clear; menu ;;
    esac
}

function only_app
{   
    verify_base 'app43_' && restore_base 'app43_' || menu

    end
}

function only_cloud
{   
    verify_base && restore_base || menu

    end
}

function both_bases
{   
    (verify_base 'app43_' && verify_base) && restore_base 'app43_'; restore_base || menu
    
    end
}

# $arg1 prefixo do nome da licen�a (app43_)
function get_file_path
{
    APP=$1

    if [[ $APP ]]
    then
        FILE_PATH_APP=$(find /home/cloud-db -type f -iname "$APP$LICENCA*.sql")
    fi    
    
    FILE_PATH_CLOUD=$(find /home/cloud-db -type f -iname "$LICENCA*.sql")

    FILE_PATH=$(find /home/cloud-db -type f -iname "$APP$LICENCA*.sql")
}

# $arg1 prefixo do nome da licen�a (app43_)
function restore_base
{
    APP=$1
    clear
    get_file_path $APP
    echo "Restaurando a base $APP$LICENCA-001..."
    echo ""
    mysql --user=root --password=root -h 127.0.0.1 < $FILE_PATH
    echo ""
    echo "Finalizado"
    sleep 1
}

# $arg1 prefixo do nome da licen�a (app43_)
# return $TRUE quando a base est� pronta para ser restaurada, return $FALSE quando tem algum problema
function verify_base()
{   
    APP=$1
    clear
    get_file_path $APP

    if [[ ! $FILE_PATH ]]
    then
        echo -e "Base nao encontrada"
        sleep 2
        return $FALSE;
    fi

    if [[ $FILE_PATH ]]
    then
        LICENCA_LOCALNAME="\`$APP$LICENCA-001\`"
        HAS_LOCAL_NAME=$(grep "$LICENCA_LOCALNAME" $FILE_PATH)
        LICENCA_PRODUCTIONNAME="\`$APP$LICENCA\`"
        HAS_PRODUCTION_NAME=$(grep "$LICENCA_PRODUCTIONNAME" $FILE_PATH)

        if [[ ! $HAS_LOCAL_NAME ]] # n�o est� pronto para restaurar a base
        then
            if [[ $HAS_PRODUCTION_NAME ]] # tem o nome da licen�a sem o -001
            then
                sed -i "s/$LICENCA_PRODUCTIONNAME/$LICENCA_LOCALNAME/g" $FILE_PATH
            else # precisa dar o CREATE DATABASE e o USE
                INPUT_TEXT="USE \`$APP$LICENCA-001\`;\n"
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
                INPUT_TEXT="CREATE DATABASE /*!32312 IF NOT EXISTS*/ \`$APP$LICENCA\-001\` /*!40100 DEFAULT CHARACTER SET latin1 */;\n"
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
                INPUT_TEXT='--\n'
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
                INPUT_TEXT="-- Current Database: \`$APP$LICENCA\-001\`"
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
                INPUT_TEXT='--'
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
            fi
        fi
        
        if [[ ! $APP ]] # se for cloud verifica se precisa dar o update pra liberar o suporte e para alterar a url
        then
            HAS_UPDATES=$(grep "UPDATE \`USUARIO\` SET \`FL_USUARIODESATIVADO_USU\` = 0 WHERE \`ID_USUARIO_USU\` = 999998;" $FILE_PATH_CLOUD)

            if [[ ! $HAS_UPDATES ]]
            then
                # mudar a url para acessar local
                UPDATE="UPDATE \`APP\` SET \`ST_URL_APP\` = REPLACE(\`ST_URL_APP\`, 'https://apps.superlogica.net/', 'http://localhost:8080/');\n"
                sed -i "$ a $UPDATE" $FILE_PATH_CLOUD
                # liberar usu�rio suporte
                UPDATE="UPDATE \`USUARIO\` SET \`FL_USUARIODESATIVADO_USU\` = 0 WHERE \`ID_USUARIO_USU\` = 999998;"
                sed -i "$ a $UPDATE" $FILE_PATH_CLOUD
            fi
        fi

    else
        return $FALSE;
    fi

    return $TRUE;
}

function end
{
    clear
    echo 'Tudo pronto para desbravar os bugs guerreiro!!! #FORCA #FOCO #FE'
    sleep 2
}
menu