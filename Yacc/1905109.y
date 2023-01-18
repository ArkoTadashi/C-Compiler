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

void delSymbolList(vector<SymbolInfo*>* symbolList) {
	for (SymbolInfo* symbol: *list) {
		delete symbol;
	}
	delete list;
}

void functionCall(SymbolInfo* &symbol, vector<SymbolInfo*>* args = NULL) {

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

start : program
	{
		//write your code in this block in all the similar blocks below
	}
	;

program : program unit 
	| unit
	;
	
unit : var_declaration
     | func_declaration
     | func_definition
     ;
     
func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
		| type_specifier ID LPAREN RPAREN SEMICOLON
		;
		 
func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement
		| type_specifier ID LPAREN RPAREN compound_statement
 		;				


parameter_list  : parameter_list COMMA type_specifier ID
		| parameter_list COMMA type_specifier
 		| type_specifier ID
		| type_specifier
 		;

 		
compound_statement : LCURL statements RCURL
 		    | LCURL RCURL
 		    ;
 		    
var_declaration : type_specifier declaration_list SEMICOLON
 		 ;
 		 
type_specifier	: INT
 		| FLOAT
 		| VOID
 		;
 		
declaration_list : declaration_list COMMA ID
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
 		  | ID
 		  | ID LTHIRD CONST_INT RTHIRD
 		  ;
 		  
statements : statement
	   | statements statement
	   ;
	   
statement : var_declaration
	  | expression_statement
	  | compound_statement
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  | IF LPAREN expression RPAREN statement
	  | IF LPAREN expression RPAREN statement ELSE statement
	  | WHILE LPAREN expression RPAREN statement
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  | RETURN expression SEMICOLON
	  ;
	  
expression_statement 	: SEMICOLON			
			| expression SEMICOLON 
			;
	  
variable : ID 		
	 | ID LTHIRD expression RTHIRD 
	 ;
	 
expression : logic_expression	
	   | variable ASSIGNOP logic_expression 	
	   ;
			
logic_expression : rel_expression 	
		 | rel_expression LOGICOP rel_expression 	
		 ;
			
rel_expression	: simple_expression 
		| simple_expression RELOP simple_expression	
		;
				
simple_expression : term 
		  | simple_expression ADDOP term 
		  ;
	// I DON"T KNOW START FROM HERE				
term :	unary_expression {
		string out = $1->getName();
		printLog(line_count, "term : unary_expression", out);
	}
    |  term MULOP unary_expression {
		string out = $1->getName() + $2->getName()  + $3->getName();
		printLog(line_count, "term : term MULOP unary_expression", out);
		checkVoidFunction($1, $3);
		if($2->getName() == "%"){
			if($3->getName() == "0") logError("Modulus by Zero");
			// Type Checking: Both the operands of the modulus operator should be integers.
			if($1->getDataType() != "int" || $3->getDataType() != "int"){
				logError("Non-Integer operand on modulus operator");
			}
			$1->setDataType("int");
			$3->setDataType("int");
		}
		$$ = new SymbolInfo(code, "term", autoTypeCasting($1,$3));
		delete $1; delete $2; delete $3;
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

