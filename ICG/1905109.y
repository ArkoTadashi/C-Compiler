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
ofstream parseout;
ofstream icgout;

SymbolTable *table = new SymbolTable(109);
int err_count = 0;

vector<SymbolInfo*>* parameterList = new vector<SymbolInfo*>;
vector<SymbolInfo*>* declareList = new vector<SymbolInfo*>;
vector<SymbolInfo*>* globalList = new vector<SymbolInfo*>;

void yyerror(const char* s) {
	cout<<"Error at line "<<line_count<<": "<<s<<"\n"<<endl;
	err_count++;
}

void debug(string s) {
	cout<<"debug: Line "<<line_count<<": "<<s<<endl<<endl;
}

void printErr(string err) {
	errout << "Line# " << line_count << ": " << err << endl;
	err_count++;
}

void printLog(string rule) {
	logout << rule << endl;
}

void deleteTree(SymbolInfo* parent) {
    for(SymbolInfo* symbol : *parent->getChildList()) {
        deleteTree(symbol);
        delete symbol;
    }
    delete parent->getChildList();
}



int labelCount = 0;
int tempCount = 0;
int globalOffset = 0;
bool locVar = false;
string funcName;


string newLabel() {
	string label;
	char *lb= new char[4];
	strcpy(lb,"    ");
	strcpy(lb,"L");
	char b[3];
	sprintf(b,"%d", labelCount);
	labelCount++;
	strcat(lb,b);
	label=lb;
	return label;
}

void asmInit(){
	icgout << ".MODEL SMALL\n.STACK 1000H\n.Data\n";
    icgout << "\tCR EQU 0DH\n\tLF EQU 0AH\n\tnumber DB \"00000$\"\n";
	for(int i = 0; i < globalList->size(); i++) {
        icgout << "\t" << (*globalList)[i]->getName() << " DW 1 DUP (0000H)\n";
    }

    icgout << ".CODE\n";
}


void newLine() {
    icgout << "new_line PROC\n\tPUSH AX\n\tPUSH DX\n\tMOV AH,2\n";
    icgout << "\tMOV dl,cr\n\tINT 21h\n\tMOV AH,2\n\tMOV dl,lf\n";
    icgout << "\tINT 21h\n\tPOP DX\n\tPOP AX\n\tRET\nnew_line ENDP\n\n";  
}

void printLn() {
    icgout << "print_output PROC  ;print what is in ax\n\tPUSH AX\n\tPUSH BX\n";
    icgout << "\tPUSH CX\n\tPUSH DX\n\tPUSH SI\n\tLEA SI,number\n\tMOV BX,10\n";
    icgout << "\tADD SI,4\n\tCMP AX,0\n\tJNGE negate\nprint:\n\tXOR DX,DX\n\tDIV BX\n\tMOV [SI],dl\n";
    icgout << "\tADD [SI],'0'\n\tDEC SI\n\tCMP AX,0\n\tJNE print\n\tINC SI\n\tLEA DX,SI\n\tMOV AH,9\n\tINT 21h\n\tPOP SI\n";
    icgout << "\tPOP DX\n\tPOP CX\n\tPOP BX\n\tPOP AX\n\tRET\nnegate:\n\tPUSH AX\n\tMOV AH,2\n\tMOV dl,'-'\n\tINT 21h\n\tPOP AX\n";
    icgout << "\tNEG AX\n\tJMP print\nprint_output ENDP\n";
}

void asmCode(SymbolInfo* symbol) {
	vector<SymbolInfo*> childList = *(symbol->getChildList());
	string label;
	
	if(symbol->getName() == "start") {
		asmInit();
		for(int i = 0; i < childList.size(); i++) {
			asmCode(childList[i]);
		}		
		newLine();
		printLn();
    	icgout << "END main\n";
	}

	else if(symbol->getName() == "func_definition") {
		icgout << childList[1]->getName() << " PROC\n";
		funcName = childList[1]->getName();

		if(childList[1]->getName() == "main") {
			icgout << "\tMOV AX, @DATA\n\tMOV DS,AX\n";
		}

		icgout << "\tPUSH BP\n\tMOV BP,SP\n";

		for(int i = 0; i < childList.size(); i++) {
			asmCode(childList[i]);
		}	

		icgout << "\tPOP BP\n";

		if(childList[1]->getName() == "main") {
			icgout << "\tMOV AH, 4CH\n\tINT 21H\n";
		}
		else{
			icgout << "\tRET\n";
		}

		icgout << childList[1]->getName() << " ENDP\n\n";

	}

	else if(symbol->getName() == "compound_statement") {
		globalOffset = 0;
		for(int i = 0; i < childList.size(); i++) {
			asmCode(childList[i]);
		}
		icgout << "\tADD SP, " << globalOffset << "\n";
	}

	else if(symbol->getName() == "declaration_list" and symbol->getType() == "declaration_list COMMA ID") {
		asmCode(childList[0]);
		// childList[2]->setOffset(0);
		if(locVar == true) {
			if(childList[2]->getType() != "ARRAY") {
				childList[2]->setOffset(globalOffset+2);
				globalOffset += 2;
				icgout << "\tSUB SP, 2\n";
			}
		}	
	}

	else if(symbol->getName() == "declaration_list") {
		// childList[0]->setOffset(0);
		if(locVar == true) {
			if(childList[0]->getType() != "ARRAY"){
				childList[0]->setOffset(globalOffset+2);
				globalOffset+=2;
				icgout << "\tSUB SP, 2\n";
			}
		}
	
	}

	else if(symbol->getName() == "statement" and symbol->getType() == "var declaration") {
		locVar = true;
		for(auto i : childList){
			asmCode(i);
		}
		locVar = false;
	}

	else if(symbol->getName() == "statement" and symbol->getType() == "FOR LPAREN expression_statement expression_statement expression RPAREN statement") {
		
		string childListart = newLabel();
		string lEnd = newLabel();
		asmCode(childList[2]);
		icgout << childListart << ":\n";
		asmCode(childList[3]);
		
		icgout << "\tJCXZ " << lEnd << "\n";
		asmCode(childList[6]);
		asmCode(childList[4]);
		icgout << "\tJMP " << childListart << "\n";
		icgout << lEnd << "" and symbol->getType() == "\n";

	}


	else if(symbol->getName()=="statement" and symbol->getType() == "IF LPAREN expression RPAREN statement ELSE statement"){
		icgout << ";S:if(B)S1 else S2 -- line " << childList[0]->getStartLine() << "\n" << newLabel() << ":\n";
		string lt=newLabel();
		string lf=newLabel();
		asmCode(childList[2]);
		icgout << "\tJCXZ " << lf << "\n\n";
		asmCode(childList[4]);	
		icgout << "\tJMP " << lt << "\n" << lf << ":\n";
		asmCode(childList[6]); 
		icgout << "" << lt << ":\n";
	}

	else if(symbol->getName() == "statement" and symbol->getType() == "IF LPAREN expression RPAREN statement") {
		icgout << ";S:if(B)S1 -- line " << childList[0]->getStartLine() << "\n" << newLabel() << ":\n";
		string lf = newLabel();
		asmCode(childList[2]);
		icgout << "\tJCXZ " << lf << "\n";
		asmCode(childList[4]);
		icgout << lf << ":\n";
	}

	

	else if(symbol->getName()=="statement" and symbol->getType() == "WHILE LPAREN expression RPAREN statement"){
		string childListart = newLabel();
		string lf=newLabel();
		icgout << ";S:while(B)S1 -- line " << childList[0]->getStartLine() << "\n" << childListart <<":\n";
		asmCode(childList[2]);
		icgout << "\tJCXZ "<<lf<<"\n\n";
		asmCode(childList[4]);	
		icgout << "\tJMP "<<childListart<<"\n"<<lf<<":\n";
 	 }

	else if(symbol->getName()=="statement" and symbol->getType() == "PRINTLN LPAREN ID RPAREN SEMICOLON"){
		if(childList[2]->getOffset()==0){
			icgout << "\tMOV AX,"<<childList[2]->getName()<<"\n\tCALL print_output\n\tCALL new_line\n";
		}
		else{
			icgout << "\tMOV AX,[BP-" <<childList[2]->getOffset()<< "]\n\tCALL print_output\n\tCALL new_line\n";
		}
	}

	else if(symbol->getName()=="statement" and symbol->getType() == "RETURN expression SEMICOLON"){
		if(funcName!="main"){
			icgout << "\t;line " <<childList[0]->getStartLine()<< ": return stmt\n";
			asmCode(childList[1]);
			icgout << "\tMOV DX,CX\n";
		}
	}

	else if(symbol->getName() == "variable" and symbol->getType() == "ID"){
		if(childList[0]->getOffset()==0){
			icgout << "\tMOV CX,"<<childList[0]->getName()<<"\n"; 
		}
		else{
			icgout << "\tMOV CX,[BP-" <<childList[0]->getOffset()<< "]\n";
		}
			
	}

	else if(symbol->getName() == "expression" and symbol->getType() == "variable ASSIGNOP logic_expression"){
		label=newLabel();
		SymbolInfo* varChild=childList[0]->getChild(0);
		icgout << ""<<label<<":";
		asmCode(childList[2]);

		if(varChild->getType()!="ARRAY"){
			if(varChild->getOffset()==0)
				icgout << "\tMOV "<<varChild->getName()<<",CX\n";
			else
				icgout << "\tMOV [BP-" <<varChild->getOffset()<< "],CX\n";		
		}

		else if(varChild->getType()=="ARRAY") { 
			cout << varChild->getOffset() << endl;
			if(varChild->getOffset()==0){
				icgout << "\tPUSH CX\n";
				asmCode(childList[0]);
				icgout << "\tPOP CX\n\tMOV [SI] , CX\n";
			}
			else{
				icgout << "\t;arr=val\n\tPUSH CX\n";
				asmCode(childList[0]);
				icgout << "\tPOP CX\n\tMOV [BX] , CX\n";
			}

			
		}
	}

	else if(symbol->getName()=="logic_expression" and symbol->getType()=="rel_expression LOGICOP rel_expression"){
		string label=newLabel();
		asmCode(childList[0]);

		if(childList[1]->getName()=="&&"){
			icgout << "\tCMP CX,0\n\tJCXZ "<<label<<"\n";
		}
		else{
			icgout << "\tCMP CX,0\n\tJNZ "<<label<<"\n";
		}

		asmCode(childList[2]);
		icgout << ""<<label<<":\n";
	}

	else if(symbol->getName() == "rel_expression" and symbol->getType() == "simple_expression RELOP simple_expression"){
		string l1 = newLabel();
		string l2 = newLabel();

		asmCode(childList[0]);
		icgout << "\tMOV AX,CX\n";
		asmCode(childList[2]);
		icgout << "\tCMP AX,CX\n";

		if(childList[1]->getName() == "<"){
			icgout << "\tJL " << l1 << "\n";
		}
		else if(childList[1]->getName()=="<="){
			icgout << "\tJLE " << l1 << "\n";
		}
		else if(childList[1]->getName()==">"){
			icgout << "\tJG " << l1 << "\n";
		}
		else if(childList[1]->getName()==">="){
			icgout << "\tJGE " << l1 << "\n";
		}
		else if(childList[1]->getName()=="=="){
			icgout << "\tJE " << l1 << "\n";
		}
		else if(childList[1]->getName()=="!="){
			icgout << "\tJNE " << l1 << "\n";
		}

		icgout << "\tMOV CX,0\n\tJMP " << l2 << "\n" << l1 << ":\n\tMOV CX,1\n" << l2 << ":";
	}

	else if(symbol->getName()=="simple_expression" and symbol->getType() == "simple_expression ADDOP term"){
		asmCode(childList[0]);
		icgout << "\tPUSH CX\n";
		asmCode(childList[2]);
		
		if(childList[1]->getName()=="+"){
			icgout << "\tPOP AX\n\tADD CX,AX\n";	
		}
		else{
			icgout << "\tPOP AX\n\tSUB AX,CX\n\tMOV CX,AX\n";
		}
	}

	else if(symbol->getName()=="term" and symbol->getType() == "term MULOP unary_expression"){
		asmCode(childList[0]);
		icgout << "\tPUSH CX\n";
		asmCode(childList[2]);
		
		if(childList[1]->getName()=="*"){
			icgout << "\tPOP AX\n\tIMUL CX\n\tMOV CX,AX\n";
		}
		else if(childList[1]->getName()=="/"){
			icgout << "\tPOP AX\n\tCWD\n\tIDIV CX\n\tMOV CX,AX\n";
		}
		else if(childList[1]->getName()=="%"){
			icgout << "\tPOP AX\n\tCWD\n\tIDIV CX\n\tMOV CX,DX\n";
		}
	
	}
	
	
	else if(symbol->getName()=="unary_expression" and symbol->getType() == "ADDOP unary_expression"){
		asmCode(childList[1]);
		if(childList[0]->getName()=="-"){
			icgout << "\tNEG CX\n"; 
		}
	}

	else if(symbol->getName()=="unary_expression" and symbol->getType() == "NOT unary_expression"){
		string l1=newLabel();
		string l2=newLabel();
		asmCode(childList[1]);
		icgout << "\tJCXZ " << l2 << "\n\tMOV CX,0\n\tJMP " << l1 << "\n" << l2 << ":\n\tMOV CX,1\n" << l1 << ":\n";

	}

	else if(symbol->getName()=="factor" and symbol->getType() == "ID LPAREN argument_list RPAREN"){
		asmCode(childList[2]);
		icgout << "\tCALL " << childList[0]->getName() << "\n\tMOV CX,DX\n\tADD SP," << childList[2]->getOffset() << "\n";
		
	}

	else if(symbol->getName()=="factor" and symbol->getType() == "CONST_INT"){
		icgout << "\tMOV CX, " << childList[0]->getName() << "\n";
	}

	else if(symbol->getName()=="factor" and symbol->getType() == "CONST_FLOAT"){
		icgout << "\tMOV CX, " << childList[0]->getName() << "\n";
	}

	else if(symbol->getName()=="factor" and symbol->getType() == "variable INCOP"){
		label=newLabel();
		icgout << "" << label << ":\n";
		
		if(childList[0]->getChild(0)->getType()!="ARRAY"){
			if(childList[0]->getChild(0)->getOffset()==0){
				icgout << "\tMOV CX, " << childList[0]->getChild(0)->getName() << "\n";
				icgout << "\tMOV AX, CX\n\tINC AX\n\tMOV " << childList[0]->getChild(0)->getName() << ",AX\n";
			}
			else{
				icgout << "\tMOV CX, [BP-" << childList[0]->getChild(0)->getOffset() << "]\n";
				icgout << "\tMOV AX, CX\n\tINC AX\n\tMOV [BP-" << childList[0]->getChild(0)->getOffset() << "],AX\n";
			}
		}
		
		else{
			if(childList[0]->getChild(0)->getOffset()==0){
				asmCode(childList[0]);
				icgout << "\tMOV AX , CX\n\tINC AX\n\tMOV [SI] , AX\n";
			}
			else{
				asmCode(childList[0]);
				icgout << "\tMOV AX , CX\n\tINC AX\n\tMOV [BX] , AX\n";
			}
		}
	
	}
	
	else if(symbol->getName()=="factor" and symbol->getType() == "variable DECOP"){
		label=newLabel();
		icgout << "" << label<< ":\n";
		
		if(childList[0]->getChild(0)->getType()!="ARRAY"){
			if(childList[0]->getChild(0)->getOffset()==0){
				icgout << "\tMOV CX, " << childList[0]->getChild(0)->getName() << "\n";
				icgout << "\tMOV AX, CX\n\tDEC AX\n\tMOV " << childList[0]->getChild(0)->getName() << ",AX\n";
			}
			else{
				icgout << "\tMOV CX, [BP-" << childList[0]->getChild(0)->getOffset()<< "]\n";
				icgout << "\tMOV AX, CX\n\tDEC AX\n\tMOV [BP-" << childList[0]->getChild(0)->getOffset()<< "],AX\n";
			}
		}
		
		else{
			if(childList[0]->getChild(0)->getOffset()==0){
				asmCode(childList[0]);
				icgout << "\tMOV AX , CX\n\tDEC AX\n\tMOV [SI] , AX\n";
			}
			else{
				asmCode(childList[0]);
				icgout << "\tMOV AX , CX\n\tDEC AX\n\tMOV [BX] , AX\n";
			}
		}
	}
	
	else if(symbol->getName()=="arguments" and symbol->getType() == "arguments COMMA logic_expression"){
		asmCode(childList[0]);
		asmCode(childList[2]);
		icgout << "\tPUSH CX\n";
	}
	
	else if(symbol->getName()=="arguments" and symbol->getType() == "logic_expression"){
		asmCode(childList[0]);
		icgout << "\tPUSH CX\n";
	}
	else{
		for(int i=0; i<childList.size(); i++){
			asmCode(childList[i]);
		}
	}  	
}



%}

%union{
	SymbolInfo* symbolInfo;
}

%token<symbolInfo> IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID BITOP INCOP DECOP ASSIGNOP NOT RETURN LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON SWITCH CASE DEFAULT CONTINUE PRINTLN STRING 
%token<symbolInfo> ADDOP MULOP RELOP LOGICOP CONST_INT CONST_FLOAT CONST_CHAR ID

%type<symbolInfo> type_specifier factor expression unary_expression simple_expression expression_statement term rel_expression logic_expression start program unit func_declaration func_definition compound_statement var_declaration statement statements variable
%type<symbolInfo> declaration_list parameter_list argument_list arguments

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
    
start : program {
		printLog("start : program");
		$$ = new SymbolInfo("start", "program");
		
		table->closeScope();
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
        $$->printChild(0, parseout);
        // deleteTree($$);

		asmCode($$);
		logout << "Total Lines: " << line_count << endl;
		logout << "Total Errors: " << err_count << endl;
	}
	;
program : program unit {
		printLog("program : program unit");
		$$ = new SymbolInfo("program", "program unit");
		$$->addChild($1);
        $$->addChild($2);
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($2->getEndLine());
	}
	| unit {
		printLog("program : unit");
		$$ = new SymbolInfo("program", "unit");
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
	}
	;

unit : var_declaration {
		printLog("unit : var_declaration");
		$$ = new SymbolInfo("unit", "var_declaration");
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
	}
    | func_declaration {
		printLog("unit : func_declaration");
		$$ = new SymbolInfo("unit", "func_declaration");
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
	}
    | func_definition {
		printLog("unit : func_definition");
		$$ = new SymbolInfo("unit", "func_definition");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
        
	}
    ;

func_declaration : type_specifier ID LPAREN parameter_list RPAREN {
				$2->setType("FUNCTION");
				$2->setDataType($1->getDataType());
				$2->setParameters(parameterList);
				parameterList->clear();
				$2->setInfoType(SymbolInfo::FUNCTION_DECLARATION);
			} SEMICOLON {
		printLog("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$ = new SymbolInfo("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
	}
	| type_specifier ID LPAREN RPAREN {
				$2->setType("FUNCTION");
				$2->setDataType($1->getDataType());
				$2->setInfoType(SymbolInfo::FUNCTION_DECLARATION);
			} SEMICOLON {
		printLog("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
		$$ = new SymbolInfo("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($6);
        $$->setEndLine($6->getEndLine());
	}
	;
func_definition : type_specifier ID LPAREN parameter_list RPAREN {
				if ($2->getInfoType() == SymbolInfo::FUNCTION_DEFINITION) {
					printErr("Redefinition of Function");
				}
				else if ($2->getInfoType() == SymbolInfo::FUNCTION_DECLARATION) {
					if ($2->getDataType() != $1->getDataType()) {
						printErr("Return type mismatch with the function declaration");
					}
					vector<SymbolInfo*>* params = $2->getParameters();
					if (params->size() < parameterList->size()) {
						printErr("Too many arguments to function '" + $2->getName() + "'");
					}
					else if (params->size() > parameterList->size()) {
						printErr("Too few arguments to function '" + $2->getName() + "'");
					}
					else {
						for (int i = 0; i < params->size(); i++) {
							SymbolInfo* symbol1 = (*params)[i];
							SymbolInfo* symbol2 = (*parameterList)[i];
							if (symbol1->getType() != symbol2->getType()) {
								printErr(string("Type mismatch for argument " + i+1) + " of '" + $2->getName() + "'");
							}
							else if (i == params->size()-1) {
								$2->setType("FUNCTION");
								$2->setDataType($1->getType());
								$2->setParameters(parameterList);
								$2->setInfoType(SymbolInfo::FUNCTION_DEFINITION);
							}
							(*params)[i]->setOffset(4+i*2);
						} 
					}
				}
				else {
					$2->setType("FUNCTION");
					$2->setDataType($1->getType());
					$2->setParameters(parameterList);
					$2->setInfoType(SymbolInfo::FUNCTION_DEFINITION);
				}
			} 
			compound_statement {
		printLog("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
		
	}
	| type_specifier ID LPAREN RPAREN {
				if ($2->getInfoType() == SymbolInfo::FUNCTION_DEFINITION) {
					printErr("Redefinition of Function");
				}
				else if ($2->getInfoType() == SymbolInfo::FUNCTION_DECLARATION) {
					if ($2->getDataType() != $1->getDataType()) {
						printErr("Return type mismatch with the function declaration");
					}
					vector<SymbolInfo*>* params = $2->getParameters();
					if (params->size()) {
						printErr("Too few arguments to function '" + $2->getName() + "'");
					}
					else {
						$2->setType("FUNCTION");
						$2->setDataType($1->getType());
						$2->setInfoType(SymbolInfo::FUNCTION_DEFINITION);
					}
				}
				else {
					$2->setType("FUNCTION");
					$2->setDataType($1->getType());
					$2->setInfoType(SymbolInfo::FUNCTION_DEFINITION);
				}
			} compound_statement {
		printLog("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
		$$ = new SymbolInfo("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($6);
        $$->setEndLine($6->getEndLine());
	}
	;

parameter_list : parameter_list COMMA type_specifier ID {
		printLog("parameter_list : parameter_list COMMA type_specifier ID");
		$$ = new SymbolInfo("parameter_list", "parameter_list COMMA type_specifier ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
		$4->setDataType($3->getDataType());
		if ($3->getType() == "void") {
			printErr("Function parameter cannot be void");
		}
		else {
			SymbolInfo* symbol = new SymbolInfo($4->getName(), $3->getType());
			parameterList->push_back(symbol);
		}
		
	}
	| parameter_list COMMA type_specifier {
		printLog("parameter_list : parameter_list COMMA type_specifier");
		$$ = new SymbolInfo("parameter_list", "parameter_list COMMA type_specifier");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
		if ($3->getType() == "void") {
			printErr("Function parameter cannot be void");
		}
		else {
			SymbolInfo* symbol = new SymbolInfo("", $3->getType());
			parameterList->push_back(symbol);
		}
	}
	| type_specifier ID {
		printLog("parameter_list : type_specifier ID");
		$$ = new SymbolInfo("parameter_list", "type_specifier ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		$2->setDataType($1->getDataType());
		if ($1->getType() == "void") {
			printErr("Function parameter cannot be void");
		}
		else {
			SymbolInfo* symbol = new SymbolInfo($2->getName(), $1->getType());
			parameterList->push_back(symbol);
		}
	}
	| type_specifier {
		printLog("parameter_list : type_specifier");
		$$ = new SymbolInfo("parameter_list", "type_specifier");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		if ($1->getType() == "void") {
			printErr("Function parameter cannot be void");
		}
		else {
			SymbolInfo* symbol = new SymbolInfo("", $1->getType());
			parameterList->push_back(symbol);
		}
	}
	;

compound_statement : LCURL {
					table->newScope();  //////////////////////////////////////////////////////////////////////////////
					for (SymbolInfo* symbol : *parameterList) {
						bool inserted = table->insert(symbol->getName(), symbol->getType());
						if(!inserted) {
							printErr("Redefinition of function parameter");
							continue;
						}
					}
					parameterList->clear();
				} 
				statements RCURL {
		printLog("compound_statement : LCURL statements RCURL");
		$$ = new SymbolInfo("compound_statement", "LCURL statements RCURL");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
		table->printAll(logout);
		table->closeScope();
	}
	| LCURL {
				table->newScope(); //////////////////////////////////////////////////////////////////////////////////////////////
				for (SymbolInfo* symbol : *parameterList) {
					bool inserted = table->insert(symbol->getName(), symbol->getType());
					if(!inserted) {
						printErr("Redefinition of Parameter");
						continue;
					}
				}
				parameterList->clear();
			} 
			RCURL {
		printLog("compound_statement : LCURL RCURL");
		$$ = new SymbolInfo("compound_statement", "LCURL RCURL");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
		table->printAll(logout);
		table->closeScope();
	}
	;

var_declaration : type_specifier declaration_list SEMICOLON {
		printLog("var_declaration : type_specifier declaration_list SEMICOLON");
		for (SymbolInfo* symbol : *declareList) {
			symbol->setDataType($1->getDataType());
			if ($1->getDataType() == "VOID") {
				printErr("Variable type cannot be void");
				continue;
			}
			bool inserted = table->insert(symbol->getName(), symbol->getType());
			if (!inserted) {
				printErr("Multiple declaration of variable");
				continue;
			}
		}
		// if (table->getNum() == 1) {
			for (SymbolInfo* symbol : *declareList) {
				globalList->push_back(symbol);
			}
		// }
		declareList->clear();
		$$ = new SymbolInfo("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
		
	}
	;

type_specifier : INT {
		printLog("type_specifier : INT");
		$$ = new SymbolInfo("type_specifier", "INT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getType());
	}
	| FLOAT {
		printLog("type_specifier : FLOAT");
		$$ = new SymbolInfo("type_specifier", "FLOAT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getType());
	}
	| VOID {
		printLog("type_specifier : VOID");
		$$ = new SymbolInfo("type_specifier", "VOID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getType());
	}
	;

declaration_list : declaration_list COMMA ID {
		printLog("declaration_list : declaration_list COMMA ID");
		$$ = new SymbolInfo("declaration_list", "declaration_list COMMA ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		declareList->push_back($3);
		$$->setDataType($1->getDataType());
		if(table->getNum()==1){
			$3->setOffset(0);
			$$->setOffset(0);		
		}
		else {
			$3->setOffset(2+$1->getOffset());
			$$->setOffset(2+$1->getOffset());
		}
		
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
		printLog("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
		$$ = new SymbolInfo("declaration_list", "declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
		SymbolInfo* symbol = new SymbolInfo($3->getName(), "ARRAY");
		symbol->setArraySize(stoi($5->getName()));
		declareList->push_back(symbol);
		$3 = (SymbolInfo*)symbol;
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($6);
        $$->setEndLine($6->getEndLine());
		$$->setDataType($1->getDataType());
		if(table->getNum()==1){
			$3->setOffset(0);
			$$->setOffset(0);			
		}
		else {
			$3->setOffset(2+$1->getOffset());
			$$->setOffset(2+$1->getOffset());
		}
	}
	| ID {
		printLog("declaration_list : ID");
		$$ = new SymbolInfo("declaration_list", "ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		declareList->push_back($1);
		$$->setDataType($1->getDataType());
		if(table->getNum()==1){
			$1->setOffset(0);	
			$$->setOffset(0);		
		}
		else {
			$1->setOffset(2);
			$$->setOffset(2);
		}
	}
	| ID LTHIRD CONST_INT RTHIRD {
		printLog("declaration_list : ID LTHIRD CONST_INT RTHIRD");
		$$ = new SymbolInfo("declaration_list", "ID LTHIRD CONST_INT RTHIRD");
		SymbolInfo* symbol = new SymbolInfo($1->getName(), "ARRAY");
		symbol->setArraySize(stoi($3->getName()));
		declareList->push_back(symbol);
		$1 = (SymbolInfo*)symbol;
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
		
		$$->setDataType($1->getDataType());

		if(table->getNum()==1){
			$1->setOffset(0);
			$$->setOffset(0);			
		}
		else {
			$1->setOffset(2);
			$$->setOffset(2);
		}
	}
	;
	
statements : statement {
		printLog("statements : statement");
		$$ = new SymbolInfo("statements", "statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}
	| statements statement {
		printLog("statements : statements statement");
		$$ = new SymbolInfo("statements", "statements statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		$$->setDataType($1->getDataType());
	}
	;
statement : var_declaration {
		printLog("statement : var_declaration");
		$$ = new SymbolInfo("statement", "var_declaration");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}	
	| expression_statement {
		printLog("statement : expression_statement");
		$$ = new SymbolInfo("statement", "expression_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}
	| compound_statement {
		printLog("statement : compound_statement");
		$$ = new SymbolInfo("statement", "compound_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		printLog("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$ = new SymbolInfo("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($6);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
		printLog("statement : IF LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	| IF LPAREN expression RPAREN statement ELSE statement {
		printLog("statement : IF LPAREN expression RPAREN statement ELSE statement");
		$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement ELSE statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($6);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
	}
	| WHILE LPAREN expression RPAREN statement {
		printLog("statement : WHILE LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("statement", "WHILE LPAREN expression RPAREN statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON {
		printLog("statement : PRINTLN LPAREN ID RPAREN SEMICOLON");
		if(!table->look_up($3->getName())){
			printErr("Undeclared variable " + $3->getName());
		}
		$$ = new SymbolInfo("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	| RETURN expression SEMICOLON {
		printLog("statement : RETURN expression SEMICOLON");
		$$ = new SymbolInfo("statement", "RETURN expression SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
	}
	;

expression_statement : SEMICOLON {
		printLog("expression_statement : SEMICOLON");
		$$ = new SymbolInfo("expression_statement", "SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}			
	| expression SEMICOLON {
		printLog("expression_statement : expression SEMICOLON");
		$$ = new SymbolInfo("expression_statement", "expression SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		$$->setDataType($1->getDataType());
	}
	;

variable : ID { 
		printLog("variable : ID");
		
		SymbolInfo *symbol = table->look_up($1->getName());
		if(symbol != NULL) {
			if(symbol->isArray()) {
				printErr("Type mismatch, " + symbol->getName() + " is an array");
			}
		}
		else {
			printErr("Undeclared variable " + $1->getName());
		}
		$$ = new SymbolInfo("variable", "ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
		$$->setOffset($1->getOffset());
	}
	| ID LTHIRD expression RTHIRD {
		printLog("variable : ID LTHIRD expression RTHIRD");
		SymbolInfo *symbol = table->look_up($1->getName());
		if(symbol != NULL) { 
			$1->setType(symbol->getType());
			if(symbol->getType() != "ARRAY"){
				printErr($1->getName() + " is not an array.");
			}
			if($3->getDataType() != "CONST_INT") {
				printErr("Expression inside third brackets not an integer");
			}
		}
		else {
			printErr("Undeclared variable " + $1->getName());
		}
		$$ = new SymbolInfo("variable", "ID LTHIRD expression RTHIRD");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->setEndLine($4->getEndLine());
		$$->setDataType($1->getDataType());
		$$->setOffset($1->getOffset());
	}
	;

expression : logic_expression {
		printLog("expression : logic_expression");
		$$ = new SymbolInfo("expression", "logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}
	| variable ASSIGNOP logic_expression {
		printLog("expression : variable ASSIGNOP logic_expression");
		SymbolInfo *symbol = table->look_up($1->getName());
		if(symbol != NULL) {
			if(symbol->getDataType() == "int" && $3->getDataType() == "float") {
				printErr("Type mismatch");
			}
		}
		if($3->getDataType() == "void") {
				printErr("Void function used in expression");
		}
		$$ = new SymbolInfo("expression", "variable ASSIGNOP logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
		$$->setDataType($1->getDataType());
	}	
	;

logic_expression : rel_expression { 
		printLog("logic_expression : rel_expression");
		$$ = new SymbolInfo("logic_expression", "rel_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
		$$->setDataType($1->getDataType());
	}	
	| rel_expression LOGICOP rel_expression {
		printLog("logic_expression : rel_expression LOGICOP rel_expression");
		$$ = new SymbolInfo("logic_expression", "rel_expression LOGICOP rel_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
		$$->setDataType($1->getDataType());
	}	
	;

rel_expression : simple_expression {
		printLog("rel_expression : simple_expression");
		$$ = new SymbolInfo("rel_expression", "simple_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}
	| simple_expression RELOP simple_expression	{
		printLog("rel_expression : simple_expression RELOP simple_expression");
		$$ = new SymbolInfo("rel_expression", "simple_expression RELOP simple_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
		$$->setDataType($1->getDataType());
	}
	;

simple_expression : term {
		printLog("simple_expression : term");
		$$ = new SymbolInfo("simple_expression", "term");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}	
	| simple_expression ADDOP term {
		printLog("simple_expression : simple_expression ADDOP term");
		// checkVoidFunc($1, $3);
		$$ = new SymbolInfo("simple_expression", " : simple_expression ADDOP term");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
		$$->setDataType($1->getDataType());
	} 
	;

term : unary_expression {
		printLog("term : unary_expression");
		$$ = new SymbolInfo("term", "unary_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}
    |  term MULOP unary_expression {
		printLog("term : term MULOP unary_expression");
		// checkVoidFunc($1, $3);
		if($2->getName() == "%"){
			if($3->getName() == "0") {
				printErr("Modulus by Zero");
			}
			if($1->getDataType() != "CONST_INT" || $3->getDataType() != "CONST_INT"){
				printErr("Non-Integer operand on modulus operator");
			}
			$1->setDataType("CONST_INT");
			$3->setDataType("CONST_INT");
		}
		$$ = new SymbolInfo("term", "term MULOP unary_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
		$$->setDataType($1->getDataType());
	}
    ;

unary_expression : ADDOP unary_expression {
		printLog("unary_expression : ADDOP unary_expression");
		$$ = new SymbolInfo("unary_expression", "ADDOP unary_expression");
		$$ = new SymbolInfo();
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	}  
	| NOT unary_expression {
		printLog("unary_expression : NOT unary_expression");
		$$ = new SymbolInfo("unary_expression", "NOT unary_expression");
		$$ = new SymbolInfo();
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	} 
	| factor {
		printLog("unary_expression : factor");
		$$ = new SymbolInfo("unary_expression", "factor");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	} 
	;
	

factor : variable {
		printLog("factor : variable");
		$$ = new SymbolInfo("factor", "variable");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
	}
	| ID LPAREN argument_list RPAREN { 
		printLog("factor : ID LPAREN argument_list RPAREN");
		//callFunction($1, $3);
		$$ = new SymbolInfo("factor", "ID LPAREN argument_list RPAREN");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
		$1->setDataType($$->getDataType());
	}
	| LPAREN expression RPAREN {
		printLog("factor : LPAREN expression RPAREN");
		$$ = new SymbolInfo("factor", "LPAREN expression RPAREN");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
	}
	| CONST_INT {
		printLog("factor : CONST_INT");
		$$ = new SymbolInfo("factor", "CONST_INT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getType());
	}
	| CONST_FLOAT { 
		printLog("factor : CONST_FLOAT");
		$$ = new SymbolInfo("factor", "CONST_FLOAT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getType());
	}
	| variable INCOP {
		printLog("factor : variable INCOP");
		$$ = new SymbolInfo("factor", "variable INCOP");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		$$->setDataType($1->getDataType());
	}
	| variable DECOP {
		printLog("factor : variable DECOP");
		$$ = new SymbolInfo("factor", "variable DECOP");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		$$->setDataType($1->getDataType());
	}
	;
	
argument_list : arguments {
		printLog("argument_list : arguments");
		$$ = new SymbolInfo("argument_list", "arguments");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
		$$->setOffset($1->getOffset());
	}
	|
	{
		printLog("argument_list : arguments");
		$$ = new SymbolInfo("argument_list", "arguments");
	}
	;
	
arguments : arguments COMMA logic_expression {
		printLog("arguments : arguments COMMA logic_expression");
		$$ = new SymbolInfo("arguments", "arguments COMMA logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
		$$->setDataType($1->getDataType());
		$$->setOffset($1->getOffset()+2);
	}
	| logic_expression {
		printLog("arguments : logic_expression");
		$$ = new SymbolInfo("arguments", "logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		$$->setDataType($1->getDataType());
		$$->setOffset(2);
	}
	;
%%


int main(int argc,char *argv[]) {

	FILE* fp;
	if((fp = freopen(argv[1], "r", stdin)) == NULL) {
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	parseout.open("parsetree.txt");
	logout.open("log.txt");
	errout.open("error.txt");
	icgout.open("icg.asm");
	
	yyin = fp;
	line_count = 1;
	yyparse();
	
	fclose(yyin);
	logout.close();
	parseout.close();
	errout.close();
	
	return 0;
}

