#!/bin/bash
#------------------------------------------------------------------
# Autor :    Gabriel Portes
# Nome  : restore_backup.sh
# Data  : 03/08/2019
#------------------------------------------------------------------

declare -r TRUE=0
declare -r FALSE=1
declare -g LICENCA=''
declare -g FILE_PATH=''
declare -g FILE_PATH_APP=''
declare -g FILE_PATH_CLOUD=''
declare -g RESTORE_OPTION=''
declare -g DB_ROOT='/home/cloud-db'

function menu
{
    clear
    echo -e ""
    echo -e "|----------------------------------------------------|"
    echo -e "|              Restaurar Backup V 1.2                |"
    echo -e "|----------------------------------------------------|"
    echo -e ""

    name_license
    select_restore_option
    backup_option
}

function name_license()
{
    echo
    echo -n "Digite o nome da licenca: "
    read LICENCA
}

select_restore_option()
{
    clear
    echo "Buscar a licenca de:"
    echo "[ 1 ] Local: cloud-db"
    echo "[ 2 ] VPN: temp"
    echo "[ 0 ] Sair"
    echo
    echo -n "Digite a opcao desejada: "
    read RESTORE_OPTION

    case $RESTORE_OPTION in
        1) clear ;;
        2) clear ;;
        0) clear; echo -e "SAINDO DO SCRIPT..." ; sleep 2; clear; exit ;;
        *) echo -e "Opcão desconhecida." ; sleep 2; clear; menu ;;
    esac
}

function backup_option()
{
    echo "Restaurar em:"
    echo "[ 1 ] Somente apps"
    echo "[ 2 ] Somente cloud"
    echo "[ 3 ] Ambos"
    echo "[ 0 ] Sair"
    echo
    echo -n "Digite a opcao desejada: "
    read OPCAO

    case $OPCAO in
        1) only_app ;;
        2) only_cloud ;;
        3) both_bases ;;
        0) clear; echo -e "SAINDO DO SCRIPT..." ; sleep 2; clear; exit ;;
        *) echo -e "Opcão desconhecida." ; sleep 2; clear; menu ;;
    esac
}

function prefix_vertical()
{
    clear
    echo -e "VERTICAL"
    echo -e "--------"
    echo "[ 1 ] Educacional"
    echo "[ 2 ] Imobiliarias"
    echo "[ 0 ] Voltar"
    echo
    echo -n "Digite a opcao da vertical desejada: "
    read VERTICAL
    case $VERTICAL in
        1) PREFIXAPP="app43_" ;;
        2) PREFIXAPP="app26_" ;;
        0) clear; menu ;;
        *) echo -e "Opcão desconhecida." ; sleep 2; clear; menu ;;
    esac
}

function only_app
{
    prefix_vertical
    verify_base "$PREFIXAPP" && restore_base "$PREFIXAPP" && end || menu

}

function only_cloud
{
    verify_base && restore_base && end || menu

}

function both_bases
{
    prefix_vertical
    verify_base "$PREFIXAPP" && verify_base && restore_base "$PREFIXAPP" && restore_base && end || menu

}

# $arg1 prefixo do nome da licença
function get_file_path
{
    APP=$1

    if [[ $RESTORE_OPTION == "2" ]]
    then
        get_db_from_vpn "$APP"
        RESTORE_OPTION=3
    fi

    if [[ $APP ]]
    then
        FILE_PATH_APP=$(find /home/cloud-db -type f -iname "$APP$LICENCA*.sql")
    fi

    FILE_PATH_CLOUD=$(find /home/cloud-db -type f -iname "$LICENCA*.sql")

    FILE_PATH=$(find /home/cloud-db -type f -iname "$APP$LICENCA*.sql")
}

# $arg1 prefixo do nome da licença
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

# $arg1 prefixo do nome da licença
# return $TRUE quando a base está pronta para ser restaurada, return $FALSE quando tem algum problema
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
        echo "Preparando arquivos para restaurar..."
        LICENCA_LOCAL_NAME="\`$APP$LICENCA-001\`"
        USE_COMMAND_LOCAL_NAME="USE $LICENCA_LOCAL_NAME;"
        HAS_USE_COMMAND_LOCAL_NAME=$(grep "$USE_COMMAND_LOCAL_NAME" $FILE_PATH)
        LICENCA_PRODUCTION_NAME="\`$APP$LICENCA\`"
        USE_COMMAND_PRODUCTION_NAME="USE $LICENCA_PRODUCTION_NAME;"
        HAS_USE_COMMAND_PRODUCTION_NAME=$(grep "$USE_COMMAND_PRODUCTION_NAME" $FILE_PATH)
        if [[ ! $HAS_USE_COMMAND_LOCAL_NAME ]] # não está pronto para restaurar a base
        then
            if [[ $HAS_USE_COMMAND_PRODUCTION_NAME ]] # tem o nome da licença sem o -001
            then
                sed -i "s/$LICENCA_PRODUCTION_NAME/$LICENCA_LOCAL_NAME/g" $FILE_PATH
            else # precisa dar o CREATE DATABASE e o USE
                INPUT_TEXT="$USE_COMMAND_LOCAL_NAME\n"
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
                INPUT_TEXT="CREATE DATABASE /*!32312 IF NOT EXISTS*/ $LICENCA_LOCAL_NAME /*!40100 DEFAULT CHARACTER SET latin1 */;\n"
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
                INPUT_TEXT='--\n'
                sed -i "17 a $INPUT_TEXT" $FILE_PATH
                INPUT_TEXT="-- Current Database: $LICENCA_LOCAL_NAME"
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
                # mudar a url para acessar local quando a base tá apontada para a master HTTPS
                UPDATE="UPDATE \`APP\` SET \`ST_URL_APP\` = REPLACE(\`ST_URL_APP\`, 'https://apps.superlogica.net/', 'http://localhost/');\n"
                sed -i "$ a $UPDATE" $FILE_PATH_CLOUD
                # mudar a url para acessar local quando a base tá apontada para a master HTTP
                UPDATE="UPDATE \`APP\` SET \`ST_URL_APP\` = REPLACE(\`ST_URL_APP\`, 'http://apps.superlogica.net/', 'http://localhost/');\n"
                sed -i "$ a $UPDATE" $FILE_PATH_CLOUD
                # mudar a url para acessar local quando a base está apontada para a estagio
                UPDATE="UPDATE \`APP\` SET \`ST_URL_APP\` = REPLACE(\`ST_URL_APP\`, 'https://estagioapps.superlogica.net/', 'http://localhost/');\n"
                sed -i "$ a $UPDATE" $FILE_PATH_CLOUD
                # liberar usuário suporte
                UPDATE="UPDATE \`USUARIO\` SET \`FL_USUARIODESATIVADO_USU\` = 0 WHERE \`ID_USUARIO_USU\` = 999998;\n"
                sed -i "$ a $UPDATE" $FILE_PATH_CLOUD
                # altera a senha de todos usuários para 'local'
                UPDATE="UPDATE \`USUARIO\` SET \`ST_AUTHTYPE_USU\` = '', \`ST_SENHA_USU\` = UPPER(MD5('local')) WHERE ID_USUARIO_USU < 999990;\n"
                sed -i "$ a $UPDATE" $FILE_PATH_CLOUD
                # criar novo usuário
                INSERT="INSERT INTO \`USUARIO\` (\`ID_USUARIO_USU\`, \`ST_NOME_USU\`, \`ST_SENHA_USU\`, \`ST_APELIDO_USU\`, \`FL_USUARIODESATIVADO_USU\`, \`ST_AUTHTYPE_USU\`, \`ST_APPTOKEN_USU\`, \`ID_USUARIOQUEAUTORIZOU_USU\`, \`ST_ACCESSTOKEN_USU\`, \`FL_TIPO_USU\`, \`ST_ACESSO_USU\`, \`ST_IPSLIBERADOS_USU\`, \`ST_CPF_USU\`, \`ST_CELULAR_USU\`, \`FL_SINCRONIZARMONGO_USU\`, \`DT_ULTIMOLOGIN_USU\`) VALUES ( 888888, 'local@local.com', UPPER(MD5('local')), 'Local', 0, '', '', NULL, '', NULL, NULL, NULL, NULL, NULL, 0, NULL);\n"
                sed -i "$ a $INSERT" $FILE_PATH_CLOUD
                # dar acesso 1000 ao novo usuário
                INSERT="INSERT INTO \`ACESSO\` VALUES (1000, 888888);\n"
                sed -i "$ a $INSERT" $FILE_PATH_CLOUD
            fi
        fi

    else
        return $FALSE;
    fi

    return $TRUE;
}

function get_db_from_vpn
{
    echo "ATENCAO: Certifique-se de estar conectado a VPN."
    echo "Aguarde... Caso necessario, forneca a senha sudo para obter a licenca da VPN."
    sudo echo

    #Temos cifs-utils instalado?
    CIFS=`dpkg  --get-selections cifs-utils 2>/dev/null`
    if [[ "$CIFS" == "" ]]
    then
        echo "Pacote cifs-utils sera instalado..."
        sudo apt update && sudo apt install -y cifs-utils
    fi
    $(sudo umount /mnt/temp)

    if [[ ! -d /mnt/temp ]]
    then
        echo "Diretorio /mnt/temp sera criado..."
        sudo mkdir -p /mnt/temp
    fi


    MOUNTED=`df | grep /mnt/temp`
    if [[ "$MOUNTED" == "" ]]
    then
        echo "Diretorio /mnt/temp sera montado..."

        VPN_DIR="filesystem.campinas.superlogica.com/temp/admin130430"
        MOUNT_CIFS=$(sudo mount -t cifs -o username=guest,password= //$VPN_DIR /mnt/temp 2>&1)

        if [[ "$MOUNT_CIFS" != "" ]]
        then
            echo "VPN nao esta conectada, tente novamente apos conectar..."
            sleep 3
            exit
        fi
    fi

    APP=$1
    if [[ $APP ]]
    then
        echo "Copiando $APP$LICENCA para /home/cloud-db..."
        DB_PATH=`find /mnt/temp/ -iname $APP$LICENCA*gz`
        BASEN=$(echo "DB_PATH" | wc -l)
        if [[ "$DB_PATH" == "" ]]
        then
            echo "Base $database nao localizada na VPN! Verifique..."
            exit
        fi
        cp $DB_PATH $DB_ROOT

        echo "Base copiada, agora extraindo..."
        cd $DB_ROOT
        gunzip $APP$LICENCA*.gz

        # caso tenha sido only apps
        if [[ "$OPCAO" == "1" ]]
        then
            return $TRUE;
        fi
    fi

    echo "Copiando $LICENCA para /home/cloud-db"
    DB_PATH=`find /mnt/temp/ -iname $LICENCA*gz`
    BASEN=$(echo "DB_PATH" | wc -l)
    if [[ "$DB_PATH" == "" ]]
    then
        echo "Base $database nao localizada na VPN! Verifique..."
        exit
    fi
    cp $DB_PATH $DB_ROOT
    echo "Base copiada, agora extraindo..."
    cd $DB_ROOT
    gunzip $LICENCA*.gz

    return $TRUE;
}

function end
{
    clear
    echo 'Tudo pronto para desbravar os bugs guerreiro!!! #FORCA #FOCO #FE'
    sleep 2
}
menu