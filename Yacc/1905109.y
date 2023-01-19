%{
#include <iostream>
#include <cstdlib>
#include <cstring>
#include <string>
#include <cmath>
#include "SymbolTable.cpp"
#define YYSTYPE SymbolInfo*

using namespace std;

int yyparse(void);
int yylex(void);

extern FILE *yyin;
extern int line_count;

ofstream logout;
ofstream errout;
int err_count = 0;

SymbolTable table = new SymbolTable(109);

void printLog(int line_cnt, string logMsg, string out) {
	logout << "Line# " << line_cnt << ": " << logMsg << "\t" << out << endl;
}
void yyerror(char *s)
{
	//write your code
}

void symbolListStr(vector<SymbolInfo*>* symbolList) {
	string out = "";
	for (SymbolInfo* symbol: *symbolList) {
		out += symbol->getName() + ",";
	}
	if (code.size() > 0) {
		out = out.substr(0, out.size()-1);
	}
}
void varDeclarationListStr(vector<SymbolInfo*>* list) {

}

void delSymbolList(vector<SymbolInfo*>* symbolList) {
	for (SymbolInfo* symbol: *list) {
		delete symbol;
	}
	delete list;
}


void functionCall(SymbolInfo* &symbol, vector<SymbolInfo*>* args = NULL) {

}

void voidFunction(SymbolInfo* symbol1, SymbolInfo* symbol2) {
	
}

void decFuncParam(int line_cnt, string dataType, string name) {
	if (dataType == "void") {
		//
		return;
	}
	if (table.insert(name, "ID")) {
		SymbolInfo* symbol = table.lookup(name);
		symbol->setDataType(dataType);
		return;
	}
	//
}

void decFuncParamList(int line_cnt, vector<SymbolInfo*>* &list) {
	if (list == NULL) {
		return;
	}
	for (SymbolInfo* symbol: *list) {
		decFuncParam(line_cnt, symbol->getDataType(), symbol->getName());
	}
	list = NULL;
}




%}

%union{
	SymbolInfo* symbolInfo;
	string str;
	vector<SymbolInfo*>* symbolInfoList;
}

%token IF ELSE FOR DO INT FLOAT VOID SWITCH DEFAULT WHILE BREAK CHAR DOUBLE RETURN CASE CONTINUE INCOP ASSIGNOP BITOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON STRING
%token<symbolInfo> ADDOP MULOP RELOP LOGICOP CONST_INT CONST_FLOAT CONST_CHAR ID

%type<symbolInfo> factor variable term unary_expression rel_expression logic_expression simple_expression expression
%type<str> type_specifier var_declaration func_declaration func_definition unit program expression_statement statement statements compound_statement
%type<symbolInfoList> arguments argument_list declaration_list parameter_list


%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE


%%

start : program {
		
	}
	;

program : program unit {

	}
	| unit {

	}
	;
	
unit : var_declaration {

	}
    | func_declaration {

	}
    | func_definition {

	}
    ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON {

	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {

	}
	;
		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement {

	}
	| type_specifier ID LPAREN RPAREN compound_statement {

	}
 	;				


parameter_list  : parameter_list COMMA type_specifier ID {

	}
	| parameter_list COMMA type_specifier {

	}
 	| type_specifier ID {

	}
	| type_specifier {

	}
 	;


//START FROM HERE BHJKSDHUKASDH
compound_statement : LCURL {table.newScope(); decFuncParamList(paramDeclineNo, funcParamList);} statements RCURL {
		string code = "{\n"+*$3+"\n}\n";
		logRule("compound_statement : LCURL statements RCURL",code);
		$$ = new string(code);
		delete $3;
		table.printAllScopeTables();table.exitScope();
	}
 	| LCURL {table.newScope();} RCURL {
		logRule("compound_statement : LCURL RCURL","{}");
		$$ = new string("{}");
		table.printAllScopeTables();table.exitScope();
	}
 	;
 		    
var_declaration : type_specifier declaration_list SEMICOLON {
		string out = *$1 +" " +  varDeclarationListStr($2) + ";";
		printLog(line_count, "var_declaration : type_specifier declaration_list SEMICOLON", out);
		$$ = new string(out);
		for(SymbolInfo* symbol : *$2){
			if (*$1 == "void") {
				//
				continue;
			}
			bool inserted = table.insert(symbol->getName(), symbol->getType());
			if (!inserted) {
				//
			}
			else {
				SymbolInfo* variable = table.lookup(symbol->getName());
				variable->setDataType(*$1);
				if (symbol->isArray()) { 
					variable->setArraySize(symbol->getArraySize());
				}
			}
		}
		delete $1; 
		delSymbolList($2);
	}
 	;
 		 
type_specifier : INT {
		printLog(line_count, "type_specifier : INT", "int");
		$$ = new string("int");
	}
 	| FLOAT {
		printLog(line_count, "type_specifier : FLOAT", "float");
		$$ = new string("float");
	}
 	| VOID {
		printLog(line_count, "type_specifier : VOID", "void");
		$$ = new string("void");
	}
 	;
 		
declaration_list : declaration_list COMMA ID {
		string out = varDeclarationListStr($1) + "," + $3->getName();
		$1->push_back($3);
		printLog(line_count, "declaration_list : declaration_list COMMA ID", out);
		$$ = $1;
	}
 	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
		string out = varDeclarationListStr($1) + "," + $3->getName() + "[" + $5->getName() + "]";
		$3->setArray($5->getName());
		$1->push_back($3);
		printLog(line_count, "declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD", out);
		$$ = $1;
		delete $5;
	}
 	| ID {
		string out = $1->getName();
		printLog(line_count, "declaration_list : ID", out);
		$$ = new vector<SymbolInfo*>();
		$$->push_back($1);
	}
 	| ID LTHIRD CONST_INT RTHIRD {
		string out = $1->getName() + "[" + $3->getName() + "]";
		printLog(line_count, "declaration_list : ID LTHIRD CONST_INT RTHIRD", out);
		$$ = new vector<SymbolInfo*>();
		$1->setArraySize($3->getName());
		$$->push_back($1);
		delete $3;
	}
 	;
 		  
statements : statement {
		printLog(line_count, "statements : statement", *$1);
		$$ = $1;
	}
	| statements statement {
		string out = *$1 + "\n" + *$2;
		printLog(line_count, "statements : statements statement", out);
		$$ = new string(out);
		delete $1, $2;
	}
	;
	   
statement : var_declaration {
		printLog(line_count, "statement : var_declaration", *$1);
	}
	| expression_statement {
		printLog(line_count, "statement : expression_statement", *$1);
	}
	| compound_statement {
		printLog(line_count, "statement : compound_statement", *$1);
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		string out = "for(" + *$3 + ";" + *$4 + ";" + $5->getName() + ")" + *$7;
		printLog(line_count, "statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement", out);
		$$ = new string(out);
		delete $3, $4, $5, $7;
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
		string out = "if(" + $3->getName() + ")" + *$5;
		printLog(line_count, "statement : IF LPAREN expression RPAREN statement", out);
		$$ = new string(out);
		delete $3, $5;
	}
	| IF LPAREN expression RPAREN statement ELSE statement {
		string out = "if(" + $3->getName() + ")" + *$5 + "else " + *$7;
		printLog(line_count, "statement : IF LPAREN expression RPAREN statement ELSE statement", out);
		$$ = new string(out);
		delete $3, $5, $7;
	}
	| WHILE LPAREN expression RPAREN statement {
		string out = "while(" + $3->getName() + ")" + *$5;
		printLog(line_count, "statement : WHILE LPAREN expression RPAREN statement", out);
		$$ = new string(out);
		delete $3, $5;
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON {
		string out = "printf(" + $3->getName() + ");";
		printLog(line_count, "statement : PRINTLN LPAREN ID RPAREN SEMICOLON", out);
		if (!table.lookup($3->getName())) {
			//
		}
		$$ = new string(out);
		delete $3;
	}
	| RETURN expression SEMICOLON {
		string out = "return " + $2->getName() + ";";
		printLog(line_count, "statement : RETURN expression SEMICOLON", out);
		$$ = new string(out);
		delete $2;
	}
	;
	  
expression_statement : SEMICOLON {
		logRule("expression_statement : SEMICOLON",";");
		$$ = new string(";");
	}		
	| expression SEMICOLON {
		string out = $1->getName() + ";";
		printLog(line_count, "expression_statement : expression SEMICOLON", out);
		$$ = new string(out);
		delete $1;
	}
	;
	  
variable : ID {
		string out = $1->getName();
		printLog(line_count, "variable : ID", out);
		SymbolInfo *info = table.lookup(out);
		if (info != NULL) {
			if(info->isArray()){
				//
			}
			$$ = new SymbolInfo(*info);
			delete $1;
		}
		else {
			//
			$$ = $1;
		}
	}
	| ID LTHIRD expression RTHIRD {
		string out = $1->getName() + "[" + $3->getName() + "]";
		printLog(line_count, "variable : ID LTHIRD expression RTHIRD", out);
		SymbolInfo *info = table.lookup($1->getName());
		if (info != NULL) {
			$1->setDataType(info->getDataType());
			if (!info->isArray()) {
				//
			}
			if ($3->getDataType() != "int") {
				//
			}
		}
		else {
			//
		}
		$1->setName(out);
		$$ = $1;
		delete $3;
	}
	;
	 
expression : logic_expression {
		string out = $1->getName();
		printLog(line_count, "expression : logic_expression", out);
		$$ = $1;
	}
	| variable ASSIGNOP logic_expression {
		string out = $1->getName() + "=" + $3->getName();
		printLog(line_count, "expression : variable ASSIGNOP logic_expression", out);
		SymbolInfo *info = table.lookup($1->getName());
		if(info != NULL){
			if(info->getDataType() == "int" && $3->getDataType() == "float"){
				//
			}
		}
		if($3->getDataType()=="void"){
			//
		}
		$$ = new SymbolInfo(out, "expression", $1->getType());
		delete $1, $3;
	}
	;
			
logic_expression : rel_expression {
		string out = $1->getName();
		printLog(line_count, "logic_expression : rel_expression", out);
	}
	| rel_expression LOGICOP rel_expression {
		string out = $1->getName() + $2->getName() + $3->getName();
		printLog(line_count, "logic_expression : rel_expression LOGICOP rel_expression", out);
		$$ = new SymbolInfo(out, "logic_expression", "int");
		delete $1, $2, $3;
	}
	;
			
rel_expression	: simple_expression {
		string out = $1->getName();
		printLog(line_count, "rel_expression : simple_expression", out);
	}
	| simple_expression RELOP simple_expression	{
		string out = $1->getName() + $2->getName() + $3->getName();
		logRule(line_count, "rel_expression : simple_expression RELOP simple_expression", out);
		autoTypeCasting($1, $3);
		$$ = new SymbolInfo(out, "rel_expression", "int");
		delete $1, $2, $3;
	}
	;
				
simple_expression : term {
		string out = $1->getName();
		printLog(line_count, "simple_expression : term", out);
	}
	| simple_expression ADDOP term {
		string out = $1->getName() + $2->getName() + $3->getName();
		printLog(line_count, "simple_expression : simple_expression ADDOP term", out);
		voidFunction($1, $3);
		$$ = new SymbolInfo(out, "simple_expression", autoTypeCasting($1, $3));
		delete $1, $2, $3;
	}
	;			
term :	unary_expression {
		string out = $1->getName();
		printLog(line_count, "term : unary_expression", out);
	}
    |  term MULOP unary_expression {
		string out = $1->getName() + $2->getName()  + $3->getName();
		printLog(line_count, "term : term MULOP unary_expression", out);
		voidFunction($1, $3);
		if($2->getName() == "%"){
			if($3->getName() == "0") {
				//
			}
			if($1->getDataType() != "int" || $3->getDataType() != "int"){
				//
			}
			$1->setDataType("int");
			$3->setDataType("int");
		}
		$$ = new SymbolInfo(code, "term", autoTypeCasting($1, $3));
		delete $1, $2, $3;
	}
    ;

unary_expression : ADDOP unary_expression {
		string out = $1->getName() + $2->getName();
		printLog(line_count, "unary_expression : ADDOP unary_expression", out);
		$$ = new SymbolInfo(out, "unary_expression", $2->getDataType());
		delete $1;
		delete $2;
	}
	| NOT unary_expression {
		string out = "!" + $2->getName();
		printLog(line_count, "unary_expression : NOT unary_expression", out);
		$$ = new SymbolInfo(out, "unary_expression", $2->getDataType());
		delete $2;
	}
	| factor {
		string out = $1->getName();
		printLog(line_count, "unary_expression : factor", out);
	} 
	;
	
factor	: variable {
		string out = $1->getName();
		printLog(line_count, "factor : variable", out);
		$$ = $1;
	}
	| ID LPAREN argument_list RPAREN {
		string out = $1->getName() + "(" + symbolListStr($3) + ")";
		printLog(line_count, "factor : ID LPAREN argument_list RPAREN", out);
		functionCall($1, $3);
		$$ = new SymbolInfo(out, "function", $1->getReturnType());
		delete $1;
		delSymbolList($3);
	}
	| LPAREN expression RPAREN {
		string out = "(" + $2->getName() + ")";
		printLog(line_count, "factor : LPAREN expression RPAREN", out);
		$$ = new SymbolInfo(out, "factor", $2->getDataType());
		delete $2;
	}
	| CONST_INT {
		string out = $1->getName();
		printLog(line_count, "factor : CONST_INT", out);
		$$ = new SymbolInfo(out, $1->getType(), "int");
	}
	| CONST_FLOAT {
		string out = $1->getName();
		printLog(line_count, "factor : CONST_FLOAT", out);
		$$ = new SymbolInfo(out, "factor", "int");
	}
	| variable INCOP {
		string out = $1->getName() + "++";
		printLog(line_count, "factor : variable INCOP", out);
		$$ = new SymbolInfo(out, "factor", $1->getDataType());
		delete $1;
	}
	| variable DECOP {
		string out = $1->getName() + "--";
		printLog(line_count, "factor : variable DECOP", out);
		$$ = new SymbolInfo(out, "factor", $1->getDataType());
		delete $1;
	}
	;
	
argument_list : arguments {
		string out = symbolInfoList($1);
		printLog(line_count, "argument_list : arguments", out);
		$$ = $1;
	}
	| {
		printLog(line_count, "argument_list :", "");
		$$ = new vector<SymbolInfo*>();
	}
			;
	
arguments : arguments COMMA logic_expression {
		string out = symbolInfoList($1) + "," + $3->getName();
		printLog(line_count, "arguments : arguments COMMA logic_expression", out);
		$$->push_back($3);
	}
	| logic_expression {
		string out - $1->getName();
		printLog(line_count, "arguments : logic_expression", out);
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

