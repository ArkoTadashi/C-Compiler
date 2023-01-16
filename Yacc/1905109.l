%option noyywrap

%{
#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <cstring>

#include "y.tab.h"

using namespace std;

extern YYSTYPE yylval;
extern SymbolTable *table;


int line_count = 1;
int err_count = 0;


FILE *logout;
FILE *tokenout;



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


INCOP ("++"|"--")
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
    fprintf(logout,"Line# %d: Token <SINGLE LINE COMMENT> Lexeme %s found\n",line_count,yytext);
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
}

{STARCOMMENT} {
    fprintf(logout,"Line# %d: Token <MULTI LINE COMMENT> Lexeme %s found\n",line_count,yytext);
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
    fprintf(logout,"Error at line# %d: UNFINISHED_COMMENT %s\n",line_count,yytext);
	err_count++;
}




{DIGITS} {
    SymbolInfo* s = new SymbolInfo(yytext, "CONST_INT");
    yylval.SymbolInfo = s;
    return CONST_INT;
}

{FLOAT} {
    SymbolInfo* s = new SymbolInfo(yytext, "CONST_FLOAT");
    yylval.SymbolInfo = s;
    return CONST_FLOAT;
}

{ILLEGAL} {
	fprintf(logout,"Error at line# %d: ILLFORMED_NUMBER %s\n",line_count,yytext);
	err_count++;
}

{TOOMANYPOINT} {
	fprintf(logout,"Error at line# %d: TOO_MANY_DECIMAL_POINTS %s\n",line_count,yytext);
	err_count++;
}

{EMPTYCHAR} {
	fprintf(logout,"Error at line# %d: EMPTY_CONST_CHAR %s\n",line_count,yytext);
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
    yylval.SymbolInfo = s;
    return CONST_CHAR;
}

{MULTICHAR} {
	fprintf(logout,"Error at line# %d: MULTICHAR_CONST_CHAR %s\n",line_count,yytext);
	err_count++;
}

{UNFINISHEDCHAR} {
	fprintf(logout,"Error at line# %d: UNFINISHED_CONST_CHAR %s\n",line_count,yytext);
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
		fprintf(tokenout,"<MULTI LINE STRING, %s>\n", yytext);
		fprintf(logout,"Line# %d: Token <MULTI LINE STRING> Lexeme %s found\n",linee,text);
	}
    else {
		fprintf(tokenout,"<SINGLE LINE STRING, %s>\n", yytext);
		fprintf(logout,"Line# %d: Token <SINGLE LINE STRING> Lexeme %s found\n",linee,text);
	}
}

{UNFINISHEDSTRING} {
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
    fprintf(logout,"Error at line# %d: UNFINISHED_STRING %s\n",line_count,yytext);
	err_count++;
}


"if"        { return IF;        }	
"else"      { return ELSE;      }
"for"       { return FOR;       }
"do"        { return DO;        }
"int"       { return INT;       }
"float"     { return FLOAT      }
"void"      { return VOID;      }
"switch"    { return SWITCH;    }
"default"   { return DEFAULT;   }
"while"     { return WHILE;     }
"break"     { return BREAK;     }
"char"      { return CHAR;      }
"double"    { return DOUBLE;    }
"return"    { return RETURN;    }
"case"      { return CASE;      }
"continue"  { return CONTINUE;  }

{INCOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "INCOP");
    yylval.SymbolInfo = s;
    return INCOP;
}

{ADDOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "ADDOP");
    yylval.SymbolInfo = s;
    return ADDOP;
}

{MULOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "MULOP");
    yylval.SymbolInfo = s;
    return MULOP;
}

{RELOP} {
	SymbolInfo* s = new SymbolInfo(yytext, "RELOP");
    yylval.SymbolInfo = s;
    return RELOP;
}

"=" { return ASSIGNOP; }

{LOGICOP} {
    SymbolInfo* s = new SymbolInfo(yytext, "LOGICOP");
    yylval.SymbolInfo = s;
    return LOGICOP;
}

{BITOP}	{
	SymbolInfo* s = new SymbolInfo(yytext, "BITOP");
    yylval.SymbolInfo = s;
    return BITOP;
}

"!" { return NOT;       }
"(" { return LPAREN;    }
")" { return RPAREN;    }
"{" { return LCURL;     }	
"}" { return RCURL;     }
"[" { return LTHIRD;    }
"]" { return RTHIRD;    }
"," { return COMMA;     }
";" { return SEMICOLON; }



{ID} {
    SymbolInfo* s = table->look_up(yytext);
    if (s == NULL) {
        s = new SymbolInfo(yytext, "ID");
    }
    yylval.SymbolInfo = s;

    return ID;
	
}

{INVALID} {
	fprintf(logout,"Error at line# %d: INVALID_ID_SUFFIX_NUM_PREFIX %s\n",line_count,yytext);
	err_count++;
}


{UNRECOGNISEDCHAR} {
	fprintf(logout,"Error at line# %d: UNRECOGNIZED_CHAR %s\n",line_count,yytext);
	err_count++;
}


			

%%

int main(int argc, char** argv) {
	if (argc != 2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1],"r");
	if (fin == NULL){
		printf("Cannot open specified file\n");
		return 0;
	}
	
	logout = fopen("1905109_log.txt","w");
	tokenout = fopen("1905109_token.txt","w");

	yyin = fin;
	yylex();
	st.printAll(logout);
    fprintf(logout, "Total lines: %d\nTotal errors: %d", line_count, err_count);
	fclose(yyin);
	fclose(tokenout);
	fclose(logout);
	return 0;
}
