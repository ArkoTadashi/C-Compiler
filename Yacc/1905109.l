%option noyywrap yylineno

%{
#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <cstring>
#include "SymbolTable.cpp"

#include "y.tab.hpp"

using namespace std;

extern YYSTYPE yylval;
extern SymbolTable *table;
extern int err_count;

extern ofstream logout;
extern ofstream errout;

int line_count;


void printError(int line_cnt, string errMsg, string symbol) {
	errout << "Error at line# "<< line_cnt << ": " << errMsg << " " << symbol << endl;
}

void printLog(int line_cnt, string logMsg, string symbol) {
	logout << "Line# " << line_cnt << ": Token <" << logMsg << "> Lexeme " << symbol << " found" << endl;
}


%}

WHITESPACE [ \t\f\r\v]+
NEWLINE [\r]?\n


NONEWLINE [^\r\n]
ALL ({NONEWLINE}|{NEWLINE})
NOSTAR [^\*]
NOSTRING [^"\\\r\n]

UNFINISHEDSTRING \"({NOSTRING}|(\\{WHITESPACE}*{ALL}))*
STRING {UNFINISHEDSTRING}\"

SLASHCOMMENT "//"({NONEWLINE}*(\\{NEWLINE})?{NONEWLINE}*)*

UNFINISHEDSTARCOMMENT ("/*")({NOSTAR}|([\*]+[^*/]))*
STARCOMMENT {UNFINISHEDSTARCOMMENT}[\*]*("*/")


LETTER [a-zA-Z]
DIGIT [0-9]
DIGITS {DIGIT}+
FLOAT {DIGITS}?(\.{DIGITS})?([Ee][+-]?{DIGITS})?

TOOMANYPOINT {DIGITS}?(((\.)+({DIGITS})?)*)?([Ee][+-]?{DIGITS})?(((\.)+({DIGITS})?)*)?
ILLEGAL {DIGITS}?(\.{DIGITS})?([Ee][+-]?{FLOAT})?

SPECIAL ("\\'"|"\\\""|"\\n"|"\\t"|"\\\\"|"\\a"|"\\f"|"\\r"|"\\b"|"\\v"|"\\0")
NOQUOTESLASH [^\\'(\r\n);]
CHR ({SPECIAL}|{NOQUOTESLASH})
CHARACTER '{CHR}'
UNFINISHEDCHAR ('({CHR})*)|('\\')
MULTICHAR '({CHR})({CHR})+'
EMPTYCHAR ''
UNRECOGNISEDCHAR ('("\\"[^{SPECIAL}]?)'|{NONEWLINE})


INCOP ("++")
DECOP ("--")
ADDOP ("+"|"-")
MULOP ("*"|"/"|"%")
RELOP ("<"|"<="|">"|">="|"=="|"!=")
LOGICOP ("&&"|"||")
BITOP ("&"|"|"|"^"|"<<"|">>")

ID [a-zA-Z_][a-zA-Z0-9_]*

INVALID ({FLOAT}{ID})



%%

{NEWLINE} {line_count++;}

{WHITESPACE} {}

{SLASHCOMMENT} {
	printLog(line_count, "SINGLE LINE COMMENT", yytext);
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
}

{STARCOMMENT} {
    printLog(line_count, "MULTI LINE COMMENT", yytext);
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
}  

{UNFINISHEDSTARCOMMENT} {
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
    printError(line_count, "UNFINISHED COMMENT", yytext);
	err_count++;
}




{DIGITS} {
    SymbolInfo* s = new SymbolInfo(yytext, "CONST_INT");
	cout << 566 << endl;
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return CONST_INT;
}

{FLOAT} {
    SymbolInfo* s = new SymbolInfo(yytext, "CONST_FLOAT");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return CONST_FLOAT;
}

{ILLEGAL} {
	printError(line_count, "ILLFORMED NUMBER", yytext);
	err_count++;
}

{TOOMANYPOINT} {
	printError(line_count, "TOO MANY DECIMAL POINTS", yytext);
	err_count++;
}

{EMPTYCHAR} {
	printError(line_count, "EMPTY_CONST_CHAR", yytext);
	err_count++;
}

{CHARACTER} {
    int off = 1;
    for (int i = 0; ; i++) {
        if (yytext[i+off] == '\0') {
            yytext[i-1] = '\0';
            break;
        }
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'n') {
			yytext[i] = '\n';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\\') {
			yytext[i] = '\\';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\'') {
			yytext[i] = '\'';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\"') {
			yytext[i] = '\"';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == 't') {
			yytext[i] = '\t';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'a') {
			yytext[i] = '\a';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'f') {
			yytext[i] = '\f';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'b') {
			yytext[i] = '\b';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'v') {
			yytext[i] = '\v';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'r') {
			yytext[i] = '\r';
			off++;
		}
		else {
			yytext[i] = yytext[i+off];
		}
    }
	SymbolInfo* s = new SymbolInfo(yytext, "CONST_CHAR");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return CONST_CHAR;
}

{MULTICHAR} {
	printError(line_count, "MULTICHAR_CONST_CHAR", yytext);
	err_count++;
}

{UNFINISHEDCHAR} {
	printError(line_count, "UNFINISHED_CONST_CHAR", yytext);
	err_count++;
}





{STRING} {
	bool multi = false;
	int linee = line_count;
	int off = 1;
	int off2 = 0;
    char text[strlen(yytext)];
    strcpy(text, yytext);
	for (int i = 0; ; i++) {
		if (yytext[i+off] == '\0') {
            yytext[i-off2-1] = '\0';
            break;
        }
        if (yytext[i+off] == '\\' and yytext[i+off+1] == '\r' and yytext[i+off+2] == '\n') {
            multi = true;
			line_count++;
			off += 2;
            off2++;
        }
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\n') {
            multi = true;
			line_count++;
			off++;
            off2++;
        }
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'n') {
			yytext[i-off2] = '\n';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\\') {
			yytext[i-off2] = '\\';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\'') {
			yytext[i-off2] = '\'';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\"') {
			yytext[i-off2] = '\"';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == 't') {
			yytext[i-off2] = '\t';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'a') {
			yytext[i-off2] = '\a';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'f') {
			yytext[i-off2] = '\f';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'b') {
			yytext[i-off2] = '\b';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'v') {
			yytext[i-off2] = '\v';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'r') {
			yytext[i-off2] = '\r';
			off++;
		}
		else {
			yytext[i-off2] = yytext[i+off];
		}
	}
	if (multi) {
		//fprintf(tokenout,"<MULTI LINE STRING, %s>\n", yytext);
		printLog(linee, "MULTI LINE STRING", yytext);
	}
    else {
		//fprintf(tokenout,"<SINGLE LINE STRING, %s>\n", yytext);
		printLog(linee, "SINGLE LINE STRING", yytext);
	}
}

{UNFINISHEDSTRING} {
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
    printError(line_count, "UNFINISHED STRING", yytext);
	err_count++;
}


"if"        { 
	SymbolInfo* s = new SymbolInfo(yytext, "IF");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return IF;        
	}	
"else"      { 
	SymbolInfo* s = new SymbolInfo(yytext, "ELSE");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return ELSE;      
	}
"for"       { 
	SymbolInfo* s = new SymbolInfo(yytext, "FOR");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return FOR;       
	}
"do"        { 
	SymbolInfo* s = new SymbolInfo(yytext, "DO");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return DO;        
	}
"int"       { 
	SymbolInfo* s = new SymbolInfo(yytext, "INT");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
	return INT;       
	}
"float"     { 
	SymbolInfo* s = new SymbolInfo(yytext, "FLOAT");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return FLOAT;     
	}
"void"      { 
	SymbolInfo* s = new SymbolInfo(yytext, "VOID");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return VOID;      
	}
"switch"    { 
	SymbolInfo* s = new SymbolInfo(yytext, "SWITCH");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return SWITCH;    
	}
"default"   { 
	SymbolInfo* s = new SymbolInfo(yytext, "DEFAULT");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return DEFAULT;   
	}
"while"     { 
	SymbolInfo* s = new SymbolInfo(yytext, "WHILE");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return WHILE;     
	}
"break"     { 
	SymbolInfo* s = new SymbolInfo(yytext, "BREAK");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return BREAK;     
	}
"char"      { 
	SymbolInfo* s = new SymbolInfo(yytext, "CHAR");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return CHAR;      
	}
"double"    { 
	SymbolInfo* s = new SymbolInfo(yytext, "DOUBLE");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return DOUBLE;    
	}
"return"    { 
	SymbolInfo* s = new SymbolInfo(yytext, "RETURN");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return RETURN;    
	}
"case"      { 
	SymbolInfo* s = new SymbolInfo(yytext, "CASE");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return CASE;      
	}
"continue"  { 
	SymbolInfo* s = new SymbolInfo(yytext, "CONTINUE");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return CONTINUE;  
	}
"printf"	{ 
	SymbolInfo* s = new SymbolInfo(yytext, "PRINTLN");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return PRINTLN;	
	}

{INCOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "INCOP");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return INCOP;
}

{DECOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "DECOP");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return DECOP;
}

{ADDOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "ADDOP");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return ADDOP;
}

{MULOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "MULOP");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return MULOP;
}

{RELOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "RELOP");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return RELOP;
}

"=" { 
	SymbolInfo* s = new SymbolInfo(yytext, "ASSIGNOP");
	cout << 77 << endl;
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return ASSIGNOP; 
	}

{LOGICOP} {
    SymbolInfo* s = new SymbolInfo(yytext, "LOGICOP");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return LOGICOP;
}

{BITOP}	{
	SymbolInfo* s = new SymbolInfo(yytext, "BITOP");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;
    return BITOP;
}

"!" { 
	SymbolInfo* s = new SymbolInfo(yytext, "NOT");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return NOT;       
	}
"(" { 
	SymbolInfo* s = new SymbolInfo(yytext, "LPAREN");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return LPAREN;    
	}
")" { 
	SymbolInfo* s = new SymbolInfo(yytext, "RPAREN");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return RPAREN;    
	}
"{" { 
	SymbolInfo* s = new SymbolInfo(yytext, "LCURL");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return LCURL;     
	}	
"}" { 
	SymbolInfo* s = new SymbolInfo(yytext, "RCURL");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return RCURL;     
	}
"[" { 
	SymbolInfo* s = new SymbolInfo(yytext, "LTHIRD");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return LTHIRD;    
	}
"]" { 
	SymbolInfo* s = new SymbolInfo(yytext, "RTHIRD");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return RTHIRD;    
	}
"," { 
	SymbolInfo* s = new SymbolInfo(yytext, "COMMA");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return COMMA;     
	}
";" { 
	SymbolInfo* s = new SymbolInfo(yytext, "SEMICOLON");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
	return SEMICOLON; 
	}



{ID} {
	
    SymbolInfo* s = new SymbolInfo(yytext, "ID");
	s->setStartLine(line_count);
	s->setEndLine(line_count);
    yylval.symbolInfo = s;

	

    return ID;
	
}

{INVALID} {
	printError(line_count, "INVALID_ID_SUFFIX_NUM_PREFIX", yytext);
	err_count++;
}


{UNRECOGNISEDCHAR} {
	printError(line_count, "UNRECOGNISED CHAR", yytext);
	err_count++;
}


			

%%
