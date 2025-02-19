%{
  #include <stdio.h>
  #include <stdlib.h>
  #include "structs.h"
  #include "symtab.h"
  extern FILE *yyin;
  extern FILE* yyout;
  #include "calculator.tab.h"

%}

%option noyywrap
%x IN_COMMENT

int [0-9]*
float ([0-9]*\.[0-9]+([eE][-+]?[0-9]+)?)|([0-9]+\.([eE][-+]?[0-9]+)?)
 /* float [0-9]*\.[0-9]*([eE][-+]?[0-9]+)? */

string \".*\"



%%

 /* SENTÈNCIES ITERATIVES: */
 /* -> INCONDICIONAL */
"repeat" { return REPEAT; }
"do"	  { return DO; }
"done"   { return DONE; }

 /* -> CONDICIÓ D'INICI */
"while"   { return WHILE; }
 /*"do"	  { return DO; }
"done"    { return DONE; } */

 /* -> CONDICIÓ FINAL */
 /*"do"	  { return DO; }*/
"until"   {return UNTIL;}

 /* -> INDEXADES */
"for"     {return FOR;}
"in"      {return IN;}
 /*"do"	  { return DO; }
"done"    { return DONE; } */

 /* -> RANGS */
".."      {return RANG;}

 /* SENTÈNCIA CONDICIONAL SENSE ALTERNATIVA */

"if"      { return IF; }
"then"    { return THEN; }
"else"    { return ELSE; }
"fi"      { return FI; }

 /* SENTÈNCIA CONDICIONAL AMB SWITCH */
"switch"  { return SWITCH;}
"fswitch" { return FSWITCH; }
"case"    { return CASE; }
"default" { return DEFAULT; }
":"	  { return COLON; }
"break"	  { return BREAK; }


 /* ENTER */
{int} {
  yylval.var.type = INTEGER;
  yylval.var.place = (char *)malloc(sizeof(char)*yyleng+1);
  strncpy(yylval.var.place, yytext, yyleng+1);
  return INT;
}

 /* REAL */
{float} {
  yylval.var.type = FLOAT;
  yylval.var.place = (char *)malloc(sizeof(char)*yyleng+1);
  strncpy(yylval.var.place, yytext, yyleng+1);
  return FL;
}

 /* COMENTARI SIMPLE */
"//".*		 { //yylval.var.type = STRING;
		   //yylval.var.value.sval = strdup(yytext);
		   return SCOMMENT; }
		      
"#".*            { //yylval.var.type = STRING;
		   //yylval.var.value.sval = strdup(yytext);
		   return SCOMMENT; }

 /* COMENTARI MULTIPLE */
"/*"([^#=].|\n)*"*/"    { //yylval.var.type = STRING;
			  //yylval.var.value.sval = strdup(yytext); /* copio tot el comentari */
			  return MCOMMENT; }

 /* OPERADORS ARITMÈTICS */
\*\*            { return POW; }

"*"             { return MUL; }
"/"             { return DIV; }
"%"             { return MOD; }

"+"             { return ADD; }
"-"             { return SUB; }

"("             { return LPAREN; }
")"             { return RPAREN; }

"\["		{ return LB; }
"\]"      	{ return RB; }

"{"             {return  LSW;}
"}"             {return  RSW;}

":="		{ return ASSIGN; }
";"		{ return PC; }
","		{ return COMA; }

 /* OPERADORS RELACIONALS */
">"             { yylval.var.type = STRING; yylval.var.place = "GT"; return BOOLOP; }
">="            { yylval.var.type = STRING; yylval.var.place = "GE"; return BOOLOP; }
"<"             { yylval.var.type = STRING; yylval.var.place = "LT"; return BOOLOP; }
"<="            { yylval.var.type = STRING; yylval.var.place = "LE"; return BOOLOP; }
"="             { yylval.var.type = STRING; yylval.var.place = "EQ"; return BOOLOP; }
"<>"            { yylval.var.type = STRING; yylval.var.place = "NE"; return BOOLOP; }

 /* OPERADORS BOOLEANS */
"not"           { return NOT; }
"and"           { return AND; }
"or"            { return OR; }

"true"  { yylval.var.type = BOOLEAN; yylval.var.place = strdup("TRUE"); return BOOL; }
"false" { yylval.var.type = BOOLEAN; yylval.var.place = strdup("FALSE"); return BOOL; }


"\n"            { return EOL; }
"\t"            {}
"\r"            {}
" "             {}
[ \t\r]+        { /* Ignora espais i tabulacions */ }

[a-zA-Z][a-zA-Z0-9]*   { yylval.var.name = (char *)malloc(sizeof(char)*yyleng+1);
                  strncpy(yylval.var.name, yytext, yyleng+1);
                  variable aux;
                  if (sym_lookup(yytext, &aux) == SYMTAB_NOT_FOUND){
                    return ID;
                  } 
                  else {  if (aux.type == BOOLEAN) return B_ID;
                          else return A_ID;
                  }
              }


. { return LERR;}
\n  { return EOL; }
\r  {}

<<EOF>> {	if (yyin) fclose(yyin);
    		return END;	}

%%
