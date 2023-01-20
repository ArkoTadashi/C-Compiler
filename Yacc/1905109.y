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
int paramDecline_cnt;

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
	cout<<"Line "<<line_count<<": "<<rule<<endl<<endl<<out<<endl<<endl;
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

void declareFunction(string funcName, string returnType, vector<SymbolInfo*>* parameterList = NULL, int line_cnt = line_count) {
	bool inserted = table.insert(funcName, "ID");
	SymbolInfo* symbol = table.look_up(funcName);
	
	if(inserted){
		info->setInfoType(SymbolInfo::FUNCTION_DECLARATION);
		info->setReturnType(returnType);
		// add functions params to the symbol info
		if(parameterList != NULL)
			for(SymbolInfo* param: *parameterList){
				info->addParameter(param->getDataType(), param->getName());
			}
		
		//debug("Function \""+funcName+"\" declared");
		//debug("Total params: "+to_string(info->getParameters().size()));
	}else{
		if(info->getInfoType()==SymbolInfo::FUNCTION_DECLARATION){
			printErr("redeclaration of "+funcName, line_cnt);
			return;
		}
	}
}

void defineFunction(string funcName, string returnType, int line_cnt=line_count, vector<SymbolInfo*>* parameterList=NULL){
	// get the symbol info to add return type and params
	SymbolInfo* info = table.look_up(funcName);

	// if the function is not declared
	// then insert it in the symbol table as ID 
	if(info==NULL){ // function name not found in the symbol table
		table.insert(funcName, "ID");
		info = table.look_up(funcName);
	}else{
			// function already declared previously
		if(info->getInfoType() == SymbolInfo::FUNCTION_DECLARATION){
			if(info->getReturnType()!=returnType){
				printErr("Return type mismatch with function declaration in function "+funcName, line_cnt);
				return;
			}
			vector<pair<string, string> > params = info->getParameters();
			int paramCnt = parameterList == NULL ? 0 : parameterList->size();
			if(params.size() != paramCnt){
				printErr("Number of arguments doesn't match prototype of the function "+funcName, line_cnt);
				return;
			}
			if(parameterList != NULL){ // for non-void functions
				vector<SymbolInfo*> paramList = *parameterList;
				for(int i=0; i<params.size(); i++){
					if(params[i].first != paramList[i]->getDataType()){
						printErr("conflicting argument types for "+funcName, line_cnt);
						return;
					}
				}
			}
		}else{ // non-function type declared with same name
			printErr(" Multiple declaration of "+funcName);
			return;
		}
	}
	if(info->getInfoType() == SymbolInfo::FUNCTION_DEFINITION){
		printErr("redefinition of "+funcName, line_cnt);
		return;
	}
	info->setInfoType(SymbolInfo::FUNCTION_DEFINITION);
	info->setReturnType(returnType);
	info->setParameters(vector<pair<string, string> >());
	// add functions params to the symbol info
	if(parameterList != NULL) // for non void functions
		for(SymbolInfo* param: *parameterList){
			info->addParameter(param->getDataType(), param->getName());
		}
}

void callFunction(SymbolInfo* &funcSym, vector<SymbolInfo*>* args = NULL){
	string funcName = funcSym->getName();
	SymbolInfo* info = table.look_up(funcName);
	if(info == NULL){
		printErr("Undeclared Function "+funcName);
		return;
	}
	if(!info->isFunction()){ // a function call cannot be made with non-function type identifier.
		printErr(funcName+" is not a function");
		return;
	}
	funcSym->setReturnType(info->getReturnType());
	if(info->getInfoType() != SymbolInfo::FUNCTION_DEFINITION){
		printErr("Function "+funcName+" not defined");
		return;
	}
	vector<pair<string, string> > params = info->getParameters();
	int paramCnt = args == NULL ? 0 : args->size();
	// Check whether a function is called with appropriate number of parameters
	if(params.size() != paramCnt){
		printErr("Total number of arguments mismatch in function "+funcName);
		return;
	}
	if(args != NULL){ // for non-void functions
		vector<SymbolInfo*> argList = *args;
		// Type Checking: During a function call all the arguments should be consistent with the function definition.
		for(int i=0; i<params.size(); i++){
			// Check whether a function is called with appropriate types. 
			if(params[i].first != argList[i]->getDataType()){
				printErr(to_string(i+1)+"th argument mismatch in function "+funcName);
				return;
			}
		}
	}
}

string autoTypeCasting(SymbolInfo* x, SymbolInfo* y){
	if(x->getDataType() == y->getDataType())
		return x->getDataType();
	if(x->getDataType() == "int" && y->getDataType() == "float"){
		x->setDataType("float");
		return "float";
	}else if(x->getDataType() == "float" && y->getDataType() == "int"){
		y->setDataType("float");
		return "float";
	}
	if(x->getDataType()!="void"){
		return x->getDataType();
	}
	return y->getDataType();
}

void checkVoidFunction(SymbolInfo* a, SymbolInfo* b){
	// Type Checking: A void function cannot be called as a part of an expression.
	if(a->getDataType() == "void" || b->getDataType() == "void"){
		printErr("Void function used in expression");
	}
}

%}
	//// read: https://stackoverflow.com/questions/1853204/yylval-and-union
%union{
	SymbolInfo* symbol_info; 
	string* str_info;
	vector<SymbolInfo*>* symbol_info_list;
}

	/* TERMINAL SYMBOLS */ 
	//////////////// keywords ////////////////
%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN
	//////////////// operators ////////////////
%token <symbol_info> ADDOP MULOP RELOP LOGICOP
%token INCOP DECOP ASSIGNOP NOT
	//////////////// puncuators ////////////////
%token LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
	//////////////// identifiers and const ////////////////
%token <symbol_info> CONST_INT CONST_FLOAT CONST_CHAR ID
	//////////////// other ////////////////
%token STRING 

	/* NON-TERMINAL SYMBOLS */
%type <symbol_info> variable factor term unary_expression simple_expression rel_expression logic_expression expression
%type <str_info> expression_statement statement statements compound_statement
%type <str_info> type_specifier var_declaration func_declaration func_definition unit program 
%type <symbol_info_list>  declaration_list parameter_list argument_list arguments

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
    /* =================== production rules ================*/
start : program { // full program parsing is done
		printLog("start : program", "");
		table.printAllScopeTables(); table.exitScope();
		cout << "Total Lines: " << line_count << endl;
		cout << "Total Errors: " << err_count << endl;
	}
	;
program : program unit { //append newly parsed unit to the end of the program
		string out = *$1 +"\n"+ *$2;
		printLog("program : program unit",out);
		$$ = new string(out);
		delete $1;delete $2;
	}
	| unit { // this is for 1st unit in the program
		printLog("program : unit",*$1);
		$$ = $1;
	}
	;
// a unit can be variable declaration or function declaration or function definition	
unit : var_declaration {
		printLog( "unit : var_declaration",*$1); //$$ = $1;
	}
    | func_declaration {
		printLog( "unit : func_declaration",*$1); //$$ = $1;
	}
    | func_definition {
		printLog( "unit : func_definition",*$1); //$$ = $1;
	}
    ;
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {
		string out = *$1 + " " + $2->getName() + "(" +funcParamListStr($4) + ");";
		printLog("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON",out);;
		$$ = new string(out);
		declareFunction($2->getName(), *$1, $4);
		//free stuff
		delete $1; delete $2; delSymbolVec($4);
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		string out = *$1 +" "+$2->getName()+"();";
		printLog("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON",out);
		declareFunction($2->getName(), *$1);
		$$ = new string(out);
		delete $1; delete $2;
	}
	;
func_definition : type_specifier ID LPAREN parameter_list RPAREN {defineFunction($2->getName(), *$1,line_count, $4);} compound_statement {
		string out = *$1 + " " + $2->getName() + "(" +funcParamListStr($4) + ")" + *$7;	
		printLog( "func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement",out);;
		$$ = new string(out);
		//cout<<"freeing for "<<$2->getName()<<endl;
		//free stuff
		delete $1; delete $2; delete $7; delSymbolVec($4);
	}
	| type_specifier ID LPAREN RPAREN {defineFunction($2->getName(), *$1,line_count);} compound_statement {
		string out = *$1 +" "+$2->getName()+"()"+ *$6;
		printLog( "func_definition : type_specifier ID LPAREN RPAREN compound_statement",out);
		$$ = new string(out);
		delete $1;delete $2;delete $6;
	}
	;				
//vector<SymbolInfo*>*
parameter_list  : parameter_list COMMA type_specifier ID { // void fun(int a, in b);
		string out = funcParamListStr($1);
		out+= ","+*$3+" "+$4->getName();
		printLog("parameter_list  : parameter_list COMMA type_specifier ID",out);
		$1->push_back(new SymbolInfo($4->getName(),"", *$3));
		$$ = $1;
		funcParamList = $1; // save the parameter to store in function scope
		paramDecline_cnt = line_count;
		delete $3; delete $4;
	}
	| parameter_list COMMA type_specifier { // void fun(int, float)
		string out = funcParamListStr($1);
		out+= "," + *$3;
		printLog("parameter_list  : parameter_list COMMA type_specifier",out);
		$1->push_back(new SymbolInfo(*$3, ""));
		$$ = $1;
		funcParamList = $1; 
		paramDecline_cnt = line_count;
		delete $3;
	}
	| type_specifier ID { // void fun(int a)
		string out = *$1 +" "+$2->getName();
		printLog("parameter_list  : type_specifier ID",out);
		$$ = new vector<SymbolInfo*>();
		$$->push_back(new SymbolInfo($2->getName(), "", *$1));
		funcParamList = $$;
		paramDecline_cnt = line_count;
		delete $1; delete $2;
	}
	// start of paramter list
	| type_specifier {// void fun(int);
		printLog("parameter_list  : type_specifier",*$1);
		// init parameter list
		$$ = new vector<SymbolInfo*>();
		$$->push_back(new SymbolInfo(*$1,"", *$1));
		delete $1;
	}
	;
compound_statement : LCURL {table.enterScope(); decFuncParamList(funcParamList, paramDecline_cnt);} statements RCURL {
		string out = "{\n"+*$3+"\n}\n";
		printLog("compound_statement : LCURL statements RCURL",out);
		$$ = new string(out);
		delete $3;
		table.printAllScopeTables();table.exitScope();
	}
	| LCURL {table.enterScope();} RCURL {
		printLog("compound_statement : LCURL RCURL","{}");
		$$ = new string("{}");
		table.printAllScopeTables();table.exitScope();
	}
	;

var_declaration : type_specifier declaration_list SEMICOLON {
		string out = *$1 +" " +  varDecListStr($2) + ";";
		printLog("var_declaration : type_specifier declaration_list SEMICOLON",out);
		$$ = new string(out);
		// decare variables in the symbol table
		for(SymbolInfo* info : *$2){
			if(*$1 == "void"){
				printErr("Variable type cannot be void");
				continue;
			}
			bool success = table.insert(info->getName(), info->getType());
			if(!success){
				printErr("Multiple declaration of "+info->getName());
			}else{
				// get the variable from symbol table
				SymbolInfo* newVar = table.look_up(info->getName());
				newVar->setDataType(*$1); // set the data type of the variable
				if(info->isArray()){ // set array size for array type variables
					newVar->setArraySize(info->getArray());
				}
			}
		}
		// free stuff
		delete $1; delSymbolVec($2);
	}
	;
type_specifier	: INT {
		printLog("type_specifier : INT","int");
		$$ = new string("int");
	}
	| FLOAT {
		printLog("type_specifier : FLOAT","float");
		$$ = new string("float");
	}
	| VOID {
		printLog("type_specifier : VOID","void");
		$$ = new string("void");
	}
	;
// vector<SymbolInfo*>*
declaration_list : declaration_list COMMA ID {
		string out = varDecListStr($1);
		out+= ","+$3->getName(); // add new variable declaration
		$1->push_back($3); // add new variable to the list
		printLog("declaration_list : declaration_list COMMA ID",out);
		$$ = $1;
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
		string out = varDecListStr($1);
		out+= "," + $3->getName()+"["+$5->getName()+"]";
		$3->setArraySize($5->getName());
		$1->push_back($3);
		printLog("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD",out);
		$$ = $1;
		delete $5; //free stuff
	}
	| ID {
		printLog("declaration_list : ID",$1->getName());
		// create list for the first symbol
		$$ = new vector<SymbolInfo*>();
		$$->push_back($1);
	}
	// for array declaration
	// for first declaration
	| ID LTHIRD CONST_INT RTHIRD {
		string out = $1->getName()+"["+$3->getName()+"]";
		printLog("declaration_list : ID LTHIRD CONST_INT RTHIRD",out);
		// create list for the first symbol
		$$ = new vector<SymbolInfo*>();
		// add the first symbol to the param list
		$1->setArraySize($3->getName());
		$$->push_back($1);

		delete $3;
	}
	;
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
		autoTypeCasting($1,$3);
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
		$$ = new SymbolInfo(out, "simple_expression", autoTypeCasting($1, $3));
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
		$$ = new SymbolInfo(out, "term", autoTypeCasting($1,$3));
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

	//logout.open("log.txt");
	errout.open("error.txt");
	
	yyin = fp;
	line_count = 1;
	yyparse();
	
	fclose(yyin);
	
	return 0;
}

