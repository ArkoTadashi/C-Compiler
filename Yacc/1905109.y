%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <cmath>
#include "SymbolTable.cpp"

using namespace std;


int yyparse(void);
int yylex(void);

extern FILE *yyin;
extern int line_count;

ofstream errout;
ofstream logout;

SymbolTable table = SymbolTable(109);
int err_count = 0;

vector<SymbolInfo*>* funcParamList = NULL;
int paramDecLine;

void yyerror(const char* s) {
	cout<<"Error at line "<<line_count<<": "<<s<<"\n"<<endl;
	//errout<<"Error at line "<<line_count<<": "<<s<<"\n"<<endl;
	err_count++;
}

void debug(string s) {
	cout<<"debug: Line "<<line_count<<": "<<s<<endl<<endl;
}

void printErr(string s, int line_cnt = -1) {
	errout<<"Error at line "<<(line_cnt == -1 ? line_count:line_cnt)<<": "<<s<<"\n"<<endl;
	cout<<"Error at line "<<(line_cnt == -1 ? line_count:line_cnt)<<": "<<s<<"\n"<<endl;
	err_count++;
}

void printLog(string rule, string out) {
	logout<<"Line "<<line_count<<": "<<rule<<endl<<endl<<out<<endl<<endl;
}

string symbolListStr(vector<SymbolInfo*>* list) {
	string out = "";
	for(SymbolInfo* symbol: *list) {
		out += symbol->getName() + ",";
	}
	if(out.size() > 0) {
		out = out.substr(0, len-1);
	}
	return out;
}

string varDecListStr(vector<SymbolInfo*>* list) {
	string out = "";
	for(SymbolInfo* symbol: *list) {
		if(symbol->getArray()=="") {
			out += symbol->getName() + ",";
		}
		else {
			out += symbol->getName() + "[" + symbol->getArray() + "],";
		}
	}
	if(out.size() > 0) {
		out = out.substr(0, out.size()-1);
	}
	return out;
}

string funcParamListStr(vector<SymbolInfo*>* list) {
	string out = "";
	for(SymbolInfo* symbol: *list) {
		out += symbol->getDataType() + " " + symbol->getName() + ",";
	}
	if(out.size() > 0) {
		out = out.substr(0, out.size()-1);
	}
	return out;
}

void delSymbolVec(vector<SymbolInfo*>* list) {
	for(SymbolInfo* symbol: *list) {
		delete symbol;
	}
	delete list;
}

void decFuncParam(string dataType, string name, int line_cnt = line_count) {
	if(dataType == "void") {
		printErr("Function parameter cannot be void");
		return;
	}
	if(table.insert(name, "ID")) { 
		SymbolInfo* symbol = table.look_up(name);
		symbol->setDataType(dataType);
		return;
	}
	printErr("Multiple declaration of " + name + " in parameter", line_cnt);
}

void decFuncParamList(vector<SymbolInfo*>* &list, int line_cnt = line_count) {
	if(list == NULL) { 
		return;
	}
	for(SymbolInfo* symbol: *list){
		decFuncParam(symbol->getDataType(), symbol->getName(), line_cnt);
	}
	list = NULL;
}

void decFunc(string funcName, string returnType, vector<SymbolInfo*>* parameterList = NULL, int line_cnt = line_count) {
	bool inserted = table.insert(funcName, "ID");
	SymbolInfo* symbol = table.look_up(funcName);
	
	if(inserted) {
		symbol->setInfoType(SymbolInfo::FUNCTION_DECLARATION);
		symbol->setReturnType(returnType);
		if(parameterList != NULL) {
			for(SymbolInfo* param: *parameterList) {
				symbol->addParameter(param->getDataType(), param->getName());
			}
		}
	}
	else {
		if(symbol->getInfoType() == SymbolInfo::FUNCTION_DECLARATION) {
			printErr("redeclaration of "+funcName, line_cnt);
			return;
		}
	}
}

void defFunc(string funcName, string returnType, int line_cnt=line_count, vector<SymbolInfo*>* parameterList=NULL) {
	SymbolInfo* symbol = table.look_up(funcName);
	if(symbol == NULL) {
		table.insert(funcName, "ID");
		symbol = table.look_up(funcName);
	}
	else {
		if(symbol->getInfoType() == SymbolInfo::FUNCTION_DECLARATION) {
			if(symbol->getReturnType() != returnType) {
				printErr("Return type mismatch with function declaration in function "+funcName, line_cnt);
				return;
			}
			vector<pair<string, string> > params = info->getParameters();
			int paramCnt = parameterList == NULL ? 0 : parameterList->size();
			if(params.size() != paramCnt) {
				printErr("Number of arguments doesn't match prototype of the function " + funcName, line_cnt);
				return;
			}
			if(parameterList != NULL) {
				vector<SymbolInfo*> paramList = *parameterList;
				for(int i = 0; i < params.size(); i++){
					if(params[i].first != paramList[i]->getDataType()) {
						printErr("conflicting argument types for " + funcName, line_cnt);
						return;
					}
				}
			}
		}
		else {
			printErr(" Multiple declaration of " + funcName);
			return;
		}
	}
	if(symbol->getInfoType() == SymbolInfo::FUNCTION_DEFINITION) {
		printErr("redefinition of " + funcName, line_cnt);
		return;
	}
	symbol->setInfoType(SymbolInfo::FUNCTION_DEFINITION);
	symbol->setReturnType(returnType);
	symbol->setParameters(vector<pair<string, string> >());
	if(parameterList != NULL) {
		for(SymbolInfo* param: *parameterList){
			symbol->addParameter(param->getDataType(), param->getName());
		}
	}
}

void callFunction(SymbolInfo* &funcSym, vector<SymbolInfo*>* args = NULL) {
	string funcName = funcSym->getName();
	SymbolInfo* symbol = table.look_up(funcName);
	if(symbol == NULL) {
		printErr("Undeclared Function " + funcName);
		return;
	}
	if(!symbol->isFunction()) {
		printErr(funcName + " is not a function");
		return;
	}
	funcSym->setReturnType(symbol->getReturnType());
	if(symbol->getInfoType() != SymbolInfo::FUNCTION_DEFINITION) {
		printErr("Function " + funcName+" not defined");
		return;
	}
	vector<pair<string, string> > params = symbol->getParameters();
	int paramCnt = args == NULL ? 0 : args->size();
	if(params.size() != paramCnt) {
		printErr("Total number of arguments mismatch in function " + funcName);
		return;
	}
	if(args != NULL) {
		vector<SymbolInfo*> argList = *args;
		for(int i = 0; i < params.size(); i++) {
			if(params[i].first != argList[i]->getDataType()) {
				printErr(to_string(i+1) + "th argument mismatch in function " + funcName);
				return;
			}
		}
	}
}

string autoTypeCast(SymbolInfo* symbol1, SymbolInfo* symbol2) {
	if(symbol1->getDataType() == symbol2->getDataType()) {
		return symbol1->getDataType();
	}

	if(symbol1->getDataType() == "int" && symbol2->getDataType() == "float") {
		symbol1->setDataType("float");
		return "float";
	}
	else if(symbol1->getDataType() == "float" && symbol2->getDataType() == "int") {
		symbol2->setDataType("float");
		return "float";
	}

	if(symbol1->getDataType()!="void") {
		return symbol1->getDataType();
	}
	return symbol2->getDataType();
}

void checkVoidFunc(SymbolInfo* symbol1, SymbolInfo* symbol2) {
	if(symbol1->getDataType() == "void" || symbol2->getDataType() == "void"){
		printErr("Void function used in expression");
	}
}

%}
%union{
	SymbolInfo* symbolInfo; 
	string* str;
	vector<SymbolInfo*>* symbolInfoList;
}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID INCOP DECOP ASSIGNOP NOT RETURN LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON SWITCH CASE DEFAULT CONTINUE PRINTLN STRING 
%token <symbolInfo> ADDOP MULOP RELOP LOGICOP CONST_INT CONST_FLOAT CONST_CHAR ID

%type <symbolInfo> variable factor term unary_expression simple_expression rel_expression logic_expression expression
%type <str> expression_statement type_specifier var_declaration func_declaration func_definition unit program statement statements compound_statement 
%type <symbolInfoList>  declaration_list parameter_list argument_list arguments

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
    
start : program {
		printLog("start : program", "");
		table.printAllScopeTables(); table.exitScope();
		cout << "Total Lines: " << line_count << endl;
		cout << "Total Errors: " << err_count << endl;
	}
	;
program : program unit {
		string out = *$1 + "\n" + *$2;
		printLog("program : program unit", out);
		$$ = new string(out);
		delete $1, $2;
	}
	| unit {
		printLog("program : unit", *$1);
		$$ = $1;
	}
	;

unit : var_declaration {
		printLog( "unit : var_declaration", *$1);
	}
    | func_declaration {
		printLog( "unit : func_declaration", *$1);
	}
    | func_definition {
		printLog( "unit : func_definition", *$1);
	}
    ;

func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
		string out = *$1 + " " + $2->getName() + "(" + funcParamListStr($4) + ");";
		printLog("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON", out);;
		$$ = new string(out);
		decFunc($2->getName(), *$1, $4);
		delete $1, $2; 
		delSymbolVec($4);
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		string out = *$1 + " " + $2->getName() + "();";
		printLog("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON", out);
		decFunc($2->getName(), *$1);
		$$ = new string(out);
		delete $1, $2;
	}
	;
func_definition : type_specifier ID LPAREN parameter_list RPAREN {defFunc($2->getName(), *$1,line_count, $4);} compound_statement {
		string out = *$1 + " " + $2->getName() + "(" +funcParamListStr($4) + ")" + *$7;	
		printLog("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement", out);
		$$ = new string(out);
		delete $1, $7; 
		delSymbolVec($4);
	}
	| type_specifier ID LPAREN RPAREN {defFunc($2->getName(), *$1, line_count);} compound_statement {
		string out = *$1 + " " + $2->getName() + "()" + *$6;
		printLog("func_definition : type_specifier ID LPAREN RPAREN compound_statement", out);
		$$ = new string(out);
		delete $1, $2, $6;
	}
	;				

parameter_list : parameter_list COMMA type_specifier ID {
		string out = funcParamListStr($1) + "," + *$3 + " " + $4->getName();
		printLog("parameter_list : parameter_list COMMA type_specifier ID", out);
		$1->push_back(new SymbolInfo($4->getName(), "", *$3));
		$$ = $1;
		funcParamList = $1;
		paramDecLine = line_count;
		delete $3, $4;
	}
	| parameter_list COMMA type_specifier {
		string out = funcParamListStr($1) + "," + *$3;
		printLog("parameter_list : parameter_list COMMA type_specifier", out);
		$1->push_back(new SymbolInfo(*$3, ""));
		$$ = $1;
		funcParamList = $1; 
		paramDecLine = line_count;
		delete $3;
	}
	| type_specifier ID {
		string out = *$1 + " " + $2->getName();
		printLog("parameter_list : type_specifier ID", out);
		$$ = new vector<SymbolInfo*>();
		$$->push_back(new SymbolInfo($2->getName(), "", *$1));
		funcParamList = $$;
		paramDecLine = line_count;
		delete $1, $2;
	}
	| type_specifier {
		printLog("parameter_list : type_specifier", *$1);
		$$ = new vector<SymbolInfo*>();
		$$->push_back(new SymbolInfo(*$1, "", *$1));
		delete $1;
	}
	;
compound_statement : LCURL {table.newScope(); decFuncParamList(funcParamList, paramDecLine);} statements RCURL {
		string out = "{\n" + *$3 + "\n}\n";
		printLog("compound_statement : LCURL statements RCURL", out);
		$$ = new string(out);
		delete $3;
		table.printAllScopeTables();
		table.exitScope();
	}
	| LCURL {table.newScope();} RCURL {
		printLog("compound_statement : LCURL RCURL", "{}");
		$$ = new string("{}");
		table.printAllScopeTables();
		table.exitScope();
	}
	;

var_declaration : type_specifier declaration_list SEMICOLON {
		string out = *$1 +" " +  varDecListStr($2) + ";";
		printLog("var_declaration : type_specifier declaration_list SEMICOLON", out);
		$$ = new string(out);
		for(SymbolInfo* symbol : *$2) {
			if(*$1 == "void") {
				printErr("Variable type cannot be void");
				continue;
			}
			bool inserted = table.insert(symbol->getName(), symbol->getType());
			if(!inserted) {
				printErr("Multiple declaration of "+symbol->getName());
			}else{
				SymbolInfo* var = table.look_up(symbol->getName());
				var->setDataType(*$1);
				if(symbol->isArray()) { 
					var->setArraySize(symbol->getArray());
				}
			}
		}
		delete $1; 
		delSymbolVec($2);
	}
	;

type_specifier	: INT {
		printLog("type_specifier : INT", "int");
		$$ = new string("int");
	}
	| FLOAT {
		printLog("type_specifier : FLOAT", "float");
		$$ = new string("float");
	}
	| VOID {
		printLog("type_specifier : VOID", "void");
		$$ = new string("void");
	}
	;

declaration_list : declaration_list COMMA ID {
		string out = varDecListStr($1) + "," + $3->getName();
		$1->push_back($3);
		printLog("declaration_list : declaration_list COMMA ID", out);
		$$ = $1;
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
		string out = varDecListStr($1) + "," + $3->getName() + "[" + $5->getName() + "]";
		$3->setArraySize($5->getName());
		$1->push_back($3);
		printLog("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD", out);
		$$ = $1;
		delete $5;
	}
	| ID {
		string out = $1->getName();
		printLog("declaration_list : ID", out);
		$$ = new vector<SymbolInfo*>();
		$$->push_back($1);
	}
	| ID LTHIRD CONST_INT RTHIRD {
		string out = $1->getName() + "[" + $3->getName() + "]";
		printLog("declaration_list : ID LTHIRD CONST_INT RTHIRD", out);
		$$ = new vector<SymbolInfo*>();
		$1->setArraySize($3->getName());
		$$->push_back($1);
		delete $3;
	}
	;
	//DOESN"T WORK AT ALL
statements : statement {
		printLog( "statements : statement",*$1);
		$$ = $1;
	}
	| statements statement {
		string out = *$1 + "\n"+ *$2;
		printLog( "statements : statements statement",out);
		$$ = new string(out);
		delete $1;delete $2;
	}
	;
statement : var_declaration {
		printLog("statement : var_declaration",*$1); // auto $$ = $1;
	}	
	| expression_statement {
		printLog("statement : expression_statement",*$1); // auto $$ = $1;
	}
	| compound_statement {
		printLog("statement : compound_statement",*$1); // auto $$ = $1;
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		string out = "for("+*$3+";"+*$4+";"+$5->getName()+")"+*$7;
		printLog("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement",out);
		$$ = new string(out);
		delete $3;delete $4;delete $5;delete $7;
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
		string out = "if("+$3->getName()+")"+*$5;
		printLog("statement : IF LPAREN expression RPAREN statement",out);
		$$ = new string(out);
		delete $3;delete $5;
	}
	| IF LPAREN expression RPAREN statement ELSE statement {
		string out = "if("+$3->getName()+")"+*$5+"else "+*$7;
		printLog("statement : IF LPAREN expression RPAREN statement ELSE statement",out);
		$$ = new string(out);
		delete $3;delete $5;delete $7;
	}
	| WHILE LPAREN expression RPAREN statement {
		string out = "while("+$3->getName()+")"+*$5;
		printLog("statement : WHILE LPAREN expression RPAREN statement",out);
		$$ = new string(out);
		delete $3;delete $5;
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON {
		string out = "printf("+$3->getName()+");";
		printLog("statement : PRINTLN LPAREN ID RPAREN SEMICOLON",out);
		if(!table.look_up($3->getName())){
			printErr("Undeclared variable  "+$3->getName());
		}
		$$ = new string(out);
		delete $3;
	}
	| RETURN expression SEMICOLON {
		string out = "return "+$2->getName()+";";
		printLog("statement : RETURN expression SEMICOLON",out);
		$$ = new string(out);
		delete $2;
	}
	;
expression_statement : SEMICOLON {
		printLog("expression_statement : SEMICOLON",";");
		$$ = new string(";");
	}			
	| expression SEMICOLON {
		string out = $1->getName() + ";";
		printLog("expression_statement : expression SEMICOLON",out);
		$$ = new string(out);
		delete $1;
	}
	;
//SymbolInfo*
variable : ID { 
		printLog("variable : ID",$1->getName());
		SymbolInfo *info = table.look_up($1->getName());
		//  check whether a variable used in an expression is declared or not
		if(info!=NULL){
			//  check whether there is an index used with array
			if(info->isArray()){
				printErr("Type mismatch, "+info->getName()+" is an array");
			}
			$$ = new SymbolInfo(*info); // copy everything
			delete $1; // free ID SymbolInfo*
		}else{
			printErr("Undeclared variable "+$1->getName());
			$$ = $1;
		}
	}
	| ID LTHIRD expression RTHIRD {
		string out = $1->getName()+"["+$3->getName()+"]";
		printLog("variable : ID LTHIRD expression RTHIRD",out);
		SymbolInfo *info = table.look_up($1->getName());
		if(info != NULL){ // symbo found in the table
			$1->setDataType(info->getDataType());
			if(!info->isArray()){ // check if the variable is array or not
				printErr($1->getName()+" is not an array.");
			}
			// Generate an error message if the index of an array is not an integer
			if($3->getDataType()!="int"){
				printErr("Expression inside third brackets not an integer");
			}
		}else{
			printErr("Undeclared variable "+$1->getName());
		}
		$1->setName(out);// new variable name
		$$ = $1;
		delete $3;
	}
	;
//SymbolInfo*
expression : logic_expression {
		printLog("expression : logic_expression",$1->getName());
		$$ = $1;
	}
	| variable ASSIGNOP logic_expression {
		string exp = $1->getName() + "=" + $3->getName();
		printLog("expression : variable ASSIGNOP logic_expression",exp);
		SymbolInfo *info = table.look_up($1->getName());
		if(info!=NULL){
			if(info->getDataType()=="int" && $3->getDataType()=="float"){
				printErr("Type mismatch");
			}
		}
		if($3->getDataType()=="void"){
				printErr("Void function used in expression");
		}
		$$ = new SymbolInfo(exp, "expression", $1->getType());
		delete $1; delete $3;
	}	
	;
//SymbolInfo*
logic_expression : rel_expression { 
		printLog("logic_expression : rel_expression",$1->getName());// $$ = $1;
	}	
	| rel_expression LOGICOP rel_expression {
		string out = $1->getName()+$2->getName()+$3->getName();
		printLog("logic_expression : rel_expression LOGICOP rel_expression",out);
		$$ = new SymbolInfo(out,"logic_expression","int");
		delete $1,$2,$3;
	}	
	;
//SymbolInfo*
rel_expression : simple_expression {
		printLog("rel_expression : simple_expression",$1->getName());
	}
	| simple_expression RELOP simple_expression	{
		string out = $1->getName()+$2->getName()+$3->getName();
		printLog("rel_expression : simple_expression RELOP simple_expression",out);
		autoTypeCast($1,$3);
		$$ = new SymbolInfo(out,"rel_expression","int");
		delete $1,$2,$3;
	}
	;
//SymbolInfo*
simple_expression : term {
		printLog("simple_expression : term",$1->getName());//$$ = $1;
		//debug($1->getName()+" : "+$1->getDataType());
	}	
	| simple_expression ADDOP term {
		string out = $1->getName() + $2->getName()  + $3->getName();
		printLog("simple_expression : simple_expression ADDOP term",out);
		checkVoidFunction($1, $3);
		$$ = new SymbolInfo(out, "simple_expression", autoTypeCast($1, $3));
		delete $1; delete $2; delete $3;
	} 
	;
//SymbolInfo*
term :	unary_expression {
		printLog("term : unary_expression",$1->getName()); //$$ = $1; 
	}
    |  term MULOP unary_expression {
		string out = $1->getName() + $2->getName()  + $3->getName();
		printLog("term : term MULOP unary_expression",out);
		checkVoidFunction($1, $3);
		if($2->getName() == "%"){
			if($3->getName() == "0") printErr("Modulus by Zero");
			// Type Checking: Both the operands of the modulus operator should be integers.
			if($1->getDataType() != "int" || $3->getDataType() != "int"){
				printErr("Non-Integer operand on modulus operator");
			}
			$1->setDataType("int");
			$3->setDataType("int");
		}
		$$ = new SymbolInfo(out, "term", autoTypeCast($1,$3));
		delete $1; delete $2; delete $3;
	}
    ;
//SymbolInfo* 
unary_expression : ADDOP unary_expression {
		string out = $1->getName() + $2->getName();
		printLog("unary_expression : ADDOP unary_expression",out);
		$$ = new SymbolInfo(out, "unary_expression", $2->getDataType());
		delete $1; delete $2;
	}  
	| NOT unary_expression {
		string out = "!"+ $2->getName();
		printLog("unary_expression : NOT unary_expression",out);
		$$ = new SymbolInfo(out, "unary_expression", $2->getDataType());
		delete $2;
	} 
	| factor {
		printLog("unary_expression : factor",$1->getName());
	} 
	;
	
//SymbolInfo*
factor	: variable {
		printLog("factor : variable",$1->getName());
		$$ = $1;
	}
	| ID LPAREN argument_list RPAREN { // function call
		string out = $1->getName() + "(" + symbolListStr($3) + ")";
		printLog("factor : ID LPAREN argument_list RPAREN",out);
		
		callFunction($1,$3);

		$$ = new SymbolInfo(out, "function", $1->getReturnType());
		debug($$->getName()+" : "+$$->getDataType());
		delete $1; delSymbolVec($3);
	}
	| LPAREN expression RPAREN {
		string out = "(" + $2->getName() + ")";
		printLog("factor : LPAREN expression RPAREN",out);
		$$ = new SymbolInfo(out, "factor", $2->getDataType());
		delete $2;
	}
	| CONST_INT { // terminal
		printLog("factor : CONST_INT", $1->getName());
		$$ = new SymbolInfo($1->getName(), $1->getType(), "int");
	}
	| CONST_FLOAT { // terminal
		printLog("factor : CONST_FLOAT",$1->getName());
		$$ = new SymbolInfo($1->getName(), "factor", "float");
	}
	| variable INCOP {
		string out = $1->getName() + "++";
		printLog("factor : variable INCOP",out);
		$$ = new SymbolInfo(out, "factor", $1->getDataType());
		delete $1;
	}
	| variable DECOP {
		string out = $1->getName() + "--";
		printLog("factor : variable DECOP",out);
		$$ = new SymbolInfo(out, "factor", $1->getDataType());
		delete $1;
	}
	;
	
//vector<SymbolInfo*>*
argument_list : arguments {
		string out = symbolListStr($1);
		printLog("argument_list : arguments",out);
		$$ = $1;
	}
	| //empty 
	{
		printLog("argument_list :","");
		$$ = new vector<SymbolInfo*>();
	}
	;
	
arguments : arguments COMMA logic_expression {
		string out = symbolListStr($1) + "," + $3->getName();
		printLog("arguments : arguments COMMA logic_expression",out);
		$$->push_back($3);
	}
	| logic_expression {
		printLog("arguments : logic_expression",$1->getName());
		$$ = new vector<SymbolInfo*>();
		$$->push_back($1);
	}
	;
%%


int main(int argc,char *argv[]) {

	FILE* fp;
	if((fp = freopen(argv[1], "r", stdin)) == NULL) {
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	logout.open("log.txt");
	errout.open("error.txt");
	
	yyin = fp;
	line_count = 1;
	yyparse();
	
	fclose(yyin);
	
	return 0;
}

