#!/bin/bash
#------------------------------------------------------------------
# Autor             :   Gabriel Portes
# Nome              :   restore_backup.sh
# Data criação      :   03/08/2019
# Data atualização  :   30/12/2024
# Como usar         :   A base que você deseja restaurar deve estar extraí­da dentro do diretório `/home/cloud-db`. Obs.: o arquivo não pode estar compactado.
#------------------------------------------------------------------

declare -r TRUE=0
declare -r FALSE=1
declare -g LICENCA=''
declare -g FILE_PATH=''

function menu
{
    clear
    echo -e ""
    echo -e "|----------------------------------------------------|"
    echo -e "|              Restaurar Backup V 1.2                |"
    echo -e "|----------------------------------------------------|"
    echo -e ""

    name_license
    backup_option
}

function name_license()
{
    echo
    echo -n "Digite o nome da licenca: "
    read LICENCA
}

function backup_option()
{
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
    echo "[ 3 ] App de integração assinaturas condomínios"
    echo "[ 4 ] Sign"
    echo "[ 0 ] Voltar"
    echo
    echo -n "Digite a opcao da vertical desejada: "
    read VERTICAL
    case $VERTICAL in
        1) PREFIXAPP="app43_" ;;
        2) PREFIXAPP="app26_" ;;
        3) PREFIXAPP="app273_" ;;
        4) PREFIXAPP="app54_" ;;
        0) clear; menu ;;
        *) echo -e "Opcão desconhecida." ; sleep 2; clear; menu ;;
    esac
}

function only_app
{
    prefix_vertical
    restore_base "$PREFIXAPP" && end || menu

}

function only_cloud
{
    restore_base && end || menu
}

function both_bases
{
    prefix_vertical
    restore_base "$PREFIXAPP" && restore_base && end || menu
}

# $arg1 prefixo do nome da licença
function get_file_path
{
    APP=$1

    FILE_PATH=$(find /home/cloud-db -type f -iname "$APP$LICENCA*.sql")

    LICENCA_LOCAL_NAME="$APP$LICENCA-001"
}

# $arg1 prefixo do nome da licença
function restore_base
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

    echo "Restaurando a base $APP$LICENCA-001..."
    echo ""
    docker exec -i superlogica-mysql mysql -uroot -proot -e "DROP DATABASE IF EXISTS \`$LICENCA_LOCAL_NAME\`"
    docker exec -i superlogica-mysql mysql -uroot -proot -e "CREATE DATABASE IF NOT EXISTS \`$LICENCA_LOCAL_NAME\`"
    docker exec -i superlogica-mysql mysql -uroot -proot -q $LICENCA_LOCAL_NAME --default-character-set=latin1 < $FILE_PATH

    if [[ ! $APP ]]
    then
        docker exec -i superlogica-mysql mysql -uroot -proot -D $LICENCA_LOCAL_NAME -e "UPDATE APP SET ST_URL_APP = REPLACE(ST_URL_APP, 'https://apps.superlogica.net/', 'http://localhost/');"
        docker exec -i superlogica-mysql mysql -uroot -proot -D $LICENCA_LOCAL_NAME -e "UPDATE APP SET ST_URL_APP = REPLACE(ST_URL_APP, 'http://apps.superlogica.net/', 'http://localhost/');"
        docker exec -i superlogica-mysql mysql -uroot -proot -D $LICENCA_LOCAL_NAME -e "UPDATE APP SET ST_URL_APP = REPLACE(ST_URL_APP, 'https://estagioapps.superlogica.net/', 'http://localhost/');"
        docker exec -i superlogica-mysql mysql -uroot -proot -D $LICENCA_LOCAL_NAME -e "UPDATE USUARIO SET FL_USUARIODESATIVADO_USU = 0 WHERE ID_USUARIO_USU = 999998;"
        docker exec -i superlogica-mysql mysql -uroot -proot -D $LICENCA_LOCAL_NAME -e "UPDATE USUARIO SET ST_AUTHTYPE_USU = '', ST_SENHA_USU = UPPER(MD5('local')) WHERE ID_USUARIO_USU < 999990;"
        docker exec -i superlogica-mysql mysql -uroot -proot -D $LICENCA_LOCAL_NAME -e "INSERT INTO USUARIO (ID_USUARIO_USU, ST_NOME_USU, ST_SENHA_USU, ST_APELIDO_USU, FL_USUARIODESATIVADO_USU, ST_AUTHTYPE_USU, ST_APPTOKEN_USU, ID_USUARIOQUEAUTORIZOU_USU, ST_ACCESSTOKEN_USU, FL_TIPO_USU, ST_ACESSO_USU, ST_IPSLIBERADOS_USU, FL_SINCRONIZARMONGO_USU, DT_ULTIMOLOGIN_USU) VALUES ( 888888, 'local@local.com', UPPER(MD5('local')), 'Local', 0, '', '', NULL, '', NULL, NULL, NULL, 0, NULL);"
        docker exec -i superlogica-mysql mysql -uroot -proot -D $LICENCA_LOCAL_NAME -e "INSERT INTO ACESSO VALUES (1000, 888888);"
    fi

    echo ""
    echo "Finalizado"
    sleep 1
}

function end
{
    clear
    echo 'Tudo pronto para desbravar os bugs guerreiro!!! #FORCA #FOCO #FE'
    sleep 2
}
menu