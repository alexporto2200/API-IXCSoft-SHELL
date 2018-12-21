#!/bin/bash

#token do usuario do sistema
TOKEN="23:4dacdb8e471a3e8cbba4e508c3c53b4547e463217b1d9b9a1d20ab4812fe1a62";
#url do sistema
URL_SISTEMA="https://url.com.br/webservice/v1";
#SELFSIGNED usa certificado autoassinado 1 sim  0 nao
SELFSIGNED=0;

#### FUNCOES
function ver_dependecias(){
	#verificar dependencias curl, jq, python
        ecurl=$(curl -V | wc -l);
        if [ $ecurl  -lt 1 ]; then
		echo "curl não está instalado";
        fi
        ejq=$(jq --version | wc -l);
        if [ $ejq  -lt 1 ]; then
                echo "jq não está instalado";
        fi
}
function ver_config(){
	#ler token do arquivo config
	valida=$(echo  $TOKEN | egrep '^(([0-9]{1,3})(:)([a-z0-9]*))$' | wc -l );
	if [ $valida -ne 1 ]; then
		echo "Token não está no formato correto";
		exit;
	else
		#passar token para base64
		TOKEN=$(echo -n $TOKEN | base64 | tr -d [:space:] );
	fi
	#saber se e auto assinado
	if [ $SELFSIGNED -eq 1 ];then
		ACEITA_SS=" -k ";
	else
		ACEITA_SS="";
	fi
	#comando curl que sera executado
	CURL_EXEC="curl -s $ACEITA_SS -H 'Authorization:Basic $TOKEN' -H 'Content-Type: application/json' -X ";
}
function validar_parametros(){
	#valida se impressao tem valor
        if [ ! -n "$IMPRIMIR" ]; then
		IMPRIMIR="y";
	fi
        #valida se parametro e json
	if [ -n "$PARAMETROS" ]; then
        	ejson=$(echo -n "$PARAMETROS" | python -m json.tool | wc -l);
        	if [ $ejson -eq 0 ] ; then
        		echo "O parametro passado em -p  precisa ser no formato json";
        	        echo "Exemplo '{\"teste\":\"teste\",\"teste2\":\"teste2\"}'";
        	        exit;
        	fi
	fi
        #valida se registro e inteiro
        einteiro=$(echo  $REGISTROID | wc -l);
        if [ $einteiro -ge 1 ]; then
                einteiro=$(echo $REGISTROID | egrep '^([0-9,]*)$' | wc -l);
                if [ $einteiro -eq 0 ] ; then
                        echo "O parametro passado em -r  precisa ser um inteiro";
                        echo "Exemplo '-r 10'";
                        exit;
                fi
        else
                REGISTROID="";
        fi
        #valida se formulario e string
	if [ -z $FORMULARIO ]; then
		echo "O parâmetro -f é obrigatório, use -f nomedoformulario";
		exit;
	else
        	estring=$(echo $FORMULARIO | egrep '^([a-z_]*)$' | wc -l);
        	if [ $estring -ne 1 ] ; then
        	        echo "O nome da formulário pode conter somente letras minúsculas";
        	        exit;
		fi
	fi
}

function tomar_acao(){
	#verifica se os parametros necessarios para acao foram passados, e toma a acao
        case $ACAO in
		#post = enviar, precisa dos parametros no formato json
                "POST")
			if [ -z "$PARAMETROS" ]; then
				echo "A opção -p é obrigatória para o método POST, use -p '{\"use\":\"json\"}'";
			else
				 inserir
			fi
                ;;
		#get = buscar, se nao tem parametros ele busca o padrao
                "GET")
			listar
                ;;
		#delete = deletar, precisa do id para deletar
                "DELETE")
                	if [ -z $REGISTROID ]; then
				echo "A opção -r é obrigatória para o método DELETE, exemplo -r 100 ou -r 100,101 ";
			else
				deletar
                        fi
                ;;
		#put =  editar, precisa de parametros e do id.
                "PUT")
			if [ -z "$PARAMETROS" ]; then
                                echo "A opção -p é obrigatória para o método PUT, exemplo -p '{\"use\":\"json\"}' ";
                        else
                                if [ -z $REGISTROID ]; then
                                        echo "A opção -r é obrigatória para o método PUT, exemplo -r 100 ou -r 100,101 ";
                                else
					editar
				fi
                        fi
                ;;
		#nenhuma acao e tomada
                *)
                        echo "Nenhuma ação valida, use: -a [ 'POST' para inserir, 'GET' para listar, 'DELETE' para deletar, 'PUT' para editar]";
                ;;
        esac
}

function editar(){
	#buscar id do formulario
        METODO_TEMP=" POST -H 'ixcsoft:listar' ";
	PARAMETROS_TEMP="{\"qtype\":\"$FORMULARIO.id\",\"query\":\"$REGISTROID\",\"oper\":\"=\"}";
        CURL_EXEC_TEMP="$CURL_EXEC $METODO_TEMP -d '$PARAMETROS_TEMP' $URL_SISTEMA/$FORMULARIO";
        RESPOSTA_TEMP=$(echo -n $CURL_EXEC_TEMP | sh | jq '.registros[0]');
	#editar os campos
	CAMPOSEDIT=$(echo $PARAMETROS | tr -d '[:space:]' | sed 's/{"/./g' | sed 's/,"/ | ./g' | sed 's/":/:/g' | sed 's/:/=/g' | sed 's/}//g');
	PARAMETROS=$(echo $RESPOSTA_TEMP | jq  "$CAMPOSEDIT" );
	#gravar a edicao
	METODO=" PUT ";
	CURL_EXEC="$CURL_EXEC $METODO -d '$PARAMETROS' $URL_SISTEMA/$FORMULARIO/$REGISTROID";
	RESPOSTA=$(echo -n $CURL_EXEC | sh );
        imprimir
}

function listar(){
	#o método get e um post que usa um cabecalho especial, por questoes de seguranca
	METODO=" POST -H 'ixcsoft:listar' ";
	CURL_EXEC="$CURL_EXEC $METODO -d '$PARAMETROS' $URL_SISTEMA/$FORMULARIO";
	RESPOSTA=$(echo -n $CURL_EXEC | sh );
	imprimir
}
function deletar(){
	METODO=" DELETE ";
	CURL_EXEC="$CURL_EXEC $METODO $URL_SISTEMA/$FORMULARIO/$REGISTROID";
	RESPOSTA=$(echo -n $CURL_EXEC | sh );
	imprimir
}
function inserir(){
	METODO=" POST ";
	CURL_EXEC="$CURL_EXEC $METODO -d '$PARAMETROS' $URL_SISTEMA/$FORMULARIO";
	RESPOSTA=$(echo -n $CURL_EXEC | sh );
	imprimir
}
function imprimir(){
	case "$IMPRIMIR" in
		"n")
			echo $RESPOSTA > /dev/null;
		;;
		"y")
			echo $RESPOSTA
		;;
		"jq")
			echo $RESPOSTA | jq
		;;
		*)
			echo $RESPOSTA
		;;
	esac
}
#####MAIN
ver_dependecias
ver_config
	if [ "$1" == "--help" ];then
		echo "";
		echo "	API CLIENT em Shell Script para integração com IXCSoft.";
		echo "	Os pré-requisitos para este script são python, curl e jq";
		echo "	Documentação da API: https://www.ixcsoft.com.br/wiki_api/provedor/"
		echo "	Abra este script no editor de texto de preferencia e altere as constantes TOKEN e URL_SISTEMA, de acordo com o sistema";
		echo "	O certificado digital é obrigatório (https). Caso o certificado seja auto assinado";
		echo "		 altere a constante SELFSIGNED=1 , caso use seja normal SELFSIGNED=0";
		echo "";
		echo "	use as opções : ";
		echo "";
		echo "	-i ['y' ou 'n' ou 'jq'] para escolher a forma de imprimir. Essa opção não é obrigatória, e o padrão é y."
		echo "		y = imprime em texto sem quebra de linha";
		echo "		n = não imprime nada";
		echo "		jq = usa jq para imprimir com cores e quebras de linha";
		echo "";
		echo "	-a ['POST' ou 'GET' ou 'DELETE' ou 'PUT'] para escolher o método que a api usará, dependendo da requisição. Este parâmetro é obrigatório";
                echo "          POST = insere dados, é obrigatório usar -f e -p em conjunto";
                echo "          GET = busca dados, é obrigatório usar -f em conjunto (Este método se chama get, mas a requisição usa post com um cabeçario especial)";
                echo "          DELETE = deleta dados,  é obrigatório usar -f e -r em conjunto";
		echo "          PUT = edita dodos,  é obrigatório usar -f , -p e  -r em conjunto";
		echo "";
		echo "	-f [nomedoformulario] para escolher sobre qual formulário a api estará trabalhando. Este parâmetro é obrigatório";
		echo "		consulte a documentação da api para ver quais formulários podem ser usados";
		echo "";
		echo "	-r [inteiro] para escolher sobre qual registro será aplicado, a edição ou o delete. Obrigatório apenas quando -a for DELETE ou PUT";
		echo "		Será necessário saber o id da trupla no formulário. Pode se obter usando o método GET";
		echo "";
		echo "	-p [ '{\"use\":\"json\"}' ] para passar pârametros de data(dados) no formato json . Obrigatório apenas quando -a for POST ou PUT. Opcional quando -a for GET";
		echo "		o formato json precisa ser válido exemplo:{\"chave\":\"valor\",\"chave\":\"valor\"}";
		echo "		para saber quais chaves e valores possíveis consulte a documentação da API";
		echo "";
		echo "";
		echo "	Abraço, Alex";
		echo "";
                echo "";
		exit;
	fi
	while getopts "a:f:p:r:i:" OPT; do
               case "$OPT" in
                        "a")
                                ACAO=${OPTARG};
                        ;;
                        "f")
                                FORMULARIO=${OPTARG};
                        ;;
                        "p")
                                PARAMETROS=${OPTARG};
                        ;;
			"r")
                                REGISTROID=${OPTARG};
                        ;;
			"i")
                                IMPRIMIR=${OPTARG};
                        ;;
                        *)
                                echo "Parâmetro inválido $OPT";
                        ;;
                esac
        done
validar_parametros
tomar_acao

