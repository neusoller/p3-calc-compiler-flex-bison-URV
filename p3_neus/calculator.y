%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include <stdbool.h>
	#include <math.h>
	#include <stdarg.h>
	#include "calculator.tab.h"

	#define MAX_QUADS 500
	#define ARRAY 3
	
	// taula de símbols pròpia
	#define CUSTOM_MAX_SYMBOLS 100
	CustomSymbol customSymtab[CUSTOM_MAX_SYMBOLS];  // Taula de símbols
	int customSymtabCount = 0;                      // Comptador d'entrades

	int errflag = 0;
	int temp = 1;
	int gdb = 0;			//used for debugging

	quad *quad_list;
	int currQuad = 0;

	extern FILE* yyin;
	extern int yylineno;

	extern int yywrap( );
	extern int yylex();
	extern void yyerror(char *explanation);

	FILE* fInfo;

	int yyterminate()
	{
	  return 0;
	}

	void yyerror(char *explanation);
	
	variable arithmeticCalc(variable v1, char* op, variable v2);
	variable powFunction(variable v1, variable v2, char* assign_name);
	
	// el meu "symtab"
	void customSymEnter(char *name, char *value, int type);
	void mostrarCustomSymtab();
	CustomSymbol *customSymLookup(char *name);
	
	char *newTemp();
	void printQuads();
	void addQuad(int num_args, ...);

	list *makelist(int i);
	list *merge(list *l1, list *l2);
	void backpatch(list *p, int l);
	
	variable generateBooleanOperation(variable v1, char *op, variable v2);
	variable generateUnaryBooleanOperation(char *op, variable v);
%}

%code requires {
  	#include "symtab.h"
	#include "structs.h"
}

%union {
    variable var;
};

%token <var> FL INT ID A_ID ADD SUB MUL DIV MOD POW BOOLOP BOOL B_ID

%token ASSIGN LPAREN RPAREN EOL END SCOMMENT MCOMMENT LERR REPEAT DO DONE LB RB PC COMA WHILE UNTIL FOR IN IF THEN ELSE FI SWITCH FSWITCH CASE DEFAULT COLON BREAK NOT AND OR RANG LSW RSW
%type <var> statement statement_list arithmetic_op1 arithmetic_op2 arithmetic_op3 arithmetic iniciar_loop acabar_loop id boolean_or boolean_and boolean_not boolean_relational boolean_arithmetic boolean M N inici_for_loop exp
%start program

%%
program : statement_list			{	backpatch($1.nextlist, currQuad);	}

statement_list : statement_list M statement 	{ 
							backpatch($1.nextlist, $2.repeat); 
							$$.nextlist = $3.nextlist;
						}
		| statement_list statement 	{ backpatch($2.nextlist, currQuad+1);}
		| statement 			{ $$.nextlist = $1.nextlist; }
		| statement_list iniciar_loop
		| statement_list acabar_loop;

iniciar_loop: REPEAT arithmetic { if($2.type == UNDEFINED){
						fprintf(fInfo, "ERROR: Condició no vàlida en el bucle REPEAT a la línia %d\n", yylineno);
						$$.type = UNDEFINED;
						yyerror($2.place);
						yylineno++;
				} else {
					if($2.type == FLOAT){
						fprintf(fInfo, "ERROR: La condició del bucle REPEAT ha de ser de tipus ENTER a la línia %d\n", yylineno);
						$$.type = UNDEFINED;
						yyerror("SEMANTIC ERROR\n");
						yylineno++;
					} else {
						
						yylineno++;
						$$ = $2;
						$$.ctr = (char *)malloc(100);
						strcpy($$.ctr, newTemp(NULL));
						addQuad(2, $$.ctr, "0");
						$$.repeat = currQuad +1;
					}
				}
			};

acabar_loop: iniciar_loop DO EOL statement_list DONE {
			fprintf(fInfo, "Línia %d: REPEAT-DO\n", yylineno); 
			if($4.type == UNDEFINED || $1.type == UNDEFINED){
				$$.type = UNDEFINED;
				yyerror("SEMANTIC ERROR: Loop error detected.\n");
			} else{
				if($1.type == INTEGER) addQuad(5, $1.ctr, ":=", $1.ctr, "ADDI", "1");
				else addQuad(5, $1.ctr, ":=", $1.ctr, "ADDF", "1");
				
				char str[20];
				sprintf(str, "%d", $1.repeat);
				if ($1.type == INTEGER)	{
					addQuad(6, "IF", $1.ctr, "LTI", $1.place, "GOTO", str);
				} else {
					addQuad(6, "IF", $1.ctr, "LTF", $1.place, "GOTO", str);
				}
			}
};



statement: id ASSIGN arithmetic {
					if($3.type == UNDEFINED){
						fprintf(fInfo, "SEMANTIC ERROR: Assignació no vàlida a la línia %d\n", yylineno);
						yyerror($3.place);
					} else {
						customSymEnter($1.name, $3.place, $3.type);

						addQuad(3, $1.name, ":=", $3.place);
						yylineno++; 
						
					}
		}
		| id ASSIGN arithmetic EOL {	
					if($3.type == UNDEFINED){
						fprintf(fInfo, "SEMANTIC ERROR: Assignació no vàlida a la línia %d\n", yylineno);
						yyerror($3.place);
					} else {
						customSymEnter($1.name, $3.place, $3.type);

						addQuad(3, $1.name, ":=", $3.place);
						yylineno++; 
						
					}
		}
		| id	{	
					if($1.type == UNDEFINED){
						yyerror($1.place);
					} else {	
												
						if(sym_lookup($1.name, &$1) == SYMTAB_NOT_FOUND) {	
							yyerror("SEMANTIC ERROR: No es troba la variable\n"); errflag = 1; YYERROR;
						} else { 
							addQuad(2, "PARAM", $1.name);
							fprintf(fInfo, "Línia %d: PARAM %s\n", yylineno, $1.name);

							if($1.type == INTEGER){
								addQuad(3, "CALL", "PUTI", "1");
								fprintf(fInfo, "Línia %d: PUTI\n", yylineno);
							} else {
								addQuad(3, "CALL", "PUTF", "1");
								fprintf(fInfo, "Línia%d: PUTF\n", yylineno);
							}
						}
					}	
					yylineno++;
		}
		
		| id LB INT RB {
				    	char *size_str = (char *)malloc(50);
				    	sprintf(size_str, "%s", $3.place);

				    	customSymEnter($1.name, size_str, ARRAY);
				    	addQuad(3, $1.name, ":= ARRAY", size_str);
		}
		| id LB INT RB ASSIGN exp {
				    	CustomSymbol *sym = customSymLookup($1.name);
				    	if (sym == NULL || sym->type != ARRAY) {
						yyerror("ERROR: La variable no és una taula o no està definida.");
				    	} else {

						char *index = newTemp($1.name);
						addQuad(4, index, "SUBI", $3.place, "1"); // Calcula l'índex correcte (base 1)

						char *addr = newTemp($1.name);
						addQuad(4, addr, "ADDI", sym->name, index); // Adreça base + desplaçament

						addQuad(3, addr, ":=", $6.place);
				    	}
		}
		
		
		| IF LPAREN boolean RPAREN THEN EOL M statement_list N ELSE M statement_list FI {
					yylineno++;
					yylineno++;
					
					backpatch($9.nextlist, currQuad+1);
					backpatch($3.truelist, $7.repeat);
					backpatch($3.falselist, $11.repeat);
					
					list * temp = merge($8.nextlist, $9.nextlist);
					$$.nextlist = merge(temp, $12.nextlist);
					
					fprintf(fInfo, "Línia %d: IF-ELSE\n", yylineno++);
		}

		| IF LPAREN boolean RPAREN THEN EOL M statement_list FI EOL{
					fprintf(fInfo, "Línia %d: IF\n", yylineno++);
					
					backpatch($3.truelist, $7.repeat);
					$$.nextlist = merge($3.falselist, $8.nextlist);
		}
		| WHILE LPAREN M boolean RPAREN DO EOL M statement_list DONE EOL {
					fprintf(fInfo, "Línia %d: WHILE-DO\n", yylineno++);
					
					backpatch($4.truelist, $8.repeat);
					$$.nextlist = $4.falselist;
					
					char * aux = malloc(sizeof(char)*10);
					sprintf(aux, "%d", $3.repeat);
					
					addQuad(2, "GOTO", aux);
					free(aux);
		}
		| DO EOL M statement_list UNTIL LPAREN boolean RPAREN EOL {
					yylineno++;
					fprintf(fInfo, "Línia %d: DO-UNTIL\n", yylineno++);
					
					backpatch($7.truelist, $3.repeat);
					$$.nextlist = merge($7.falselist, $4.nextlist);
		}
		| inici_for_loop DO EOL statement_list DONE EOL	{
			yylineno++;
			addQuad(5, $1.name, ":=", $1.name, "ADDI", "1");
			
			char * aux = malloc(sizeof(char)*10);
			sprintf(aux, "%d", $1.repeat);
			addQuad(2, "GOTO", aux);
			
			char * aux2 = malloc(sizeof(char)*10);
			sprintf(aux2, "%d", currQuad+1);
			quad_list[$1.repeat].label = malloc(sizeof(char) * 100 + 1);
			strcpy(quad_list[$1.repeat].label , aux2);

			free(aux);
			free(aux2);
			fprintf(fInfo, "Línia %d: final FOR\n", yylineno++);
		}
		| EOL		{ yylineno++;}
		| SCOMMENT	{ fprintf(fInfo, "Línia %d: Comentari simple\n", yylineno);yylineno++; }
		| MCOMMENT	{ fprintf(fInfo, "Línia %d: Comentari múltiple\n", yylineno);yylineno++; }
		| END		{ fprintf(fInfo, "Línia %d: Final fitxer\n", yylineno); YYABORT;}
		| LERR EOL	{ yyerror("Error lèxic: caràcter invàlid. (LERR EOL)\n"); yylineno++; }
		| LERR 		{ yyerror("Error lèxic: caràcter invàlid. (LERR)\n"); }
		| error	EOL	{	if (errflag == 1) errflag = 0;
					else fprintf(fInfo,"\nLínia %d: Error síntàctic: No hi ha cap regla que coicideixi. (error EOL)\n", yylineno);
					yylineno++;
				} ;
id: ID | A_ID | B_ID;
exp: arithmetic | boolean;

inici_for_loop: FOR A_ID IN arithmetic RANG arithmetic {
	if($2.type != INTEGER){
		$$.type = UNDEFINED;
		yyerror("SEMANTIC ERROR: No es pot inicialitzar el bucle\n");
		yylineno++;
	} else{ 
		fprintf(fInfo, "Línia %d: inici FOR\n", yylineno++);
		addQuad(3, $2.name, ":=", $4.place);
		fprintf(fInfo, "Línia %d: Assignació -> %s := %s\n", yylineno, $2.name, $4.place); 
		$$.place = $4.place;
		$$.repeat = currQuad;
		$$.name = $2.name;
		addQuad(5, "IF", $2.name, "LEI", $6.place, "GOTO");
	}
};

M: { $$.repeat = currQuad+1; };

N: { $$.nextlist = makelist(currQuad); addQuad(1, "GOTO");};

arithmetic: arithmetic_op1 
		| arithmetic ADD arithmetic_op1		{ $$ = arithmeticCalc($1, "+", $3); }
		| arithmetic SUB arithmetic_op1		{ $$ = arithmeticCalc($1, "-", $3); }
		| ADD arithmetic_op1			{ ($$ = $2); }
		| SUB arithmetic_op2			{	$$.type = $2.type;
								$$.place = newTemp(NULL);
								
								if ($2.type == INTEGER) sprintf($$.place, "-%s", $2.place);
							    	else sprintf($$.place, "-%s", $2.place);

								if($2.type == INTEGER) addQuad(3, $$.place, "CHSI", $2.place);
								else addQuad(3, $$.place, "CHSF", $2.place);
							} ;
							
arithmetic_op1: arithmetic_op2 
		| arithmetic_op1 MUL arithmetic_op2 	{ $$ = arithmeticCalc($1, "*", $3); }
		| arithmetic_op1 DIV arithmetic_op2 	{ $$ = arithmeticCalc($1, "/", $3); }
		| arithmetic_op1 MOD arithmetic_op2	{ $$ = arithmeticCalc($1, "%", $3); };

arithmetic_op2: arithmetic_op3 
		| arithmetic_op3 POW arithmetic_op2	{ $$ = arithmeticCalc($1, "**", $3); };

arithmetic_op3: LPAREN arithmetic RPAREN	{ $$ = $2; }
		| INT 				{	if($1.type == UNDEFINED) yyerror($1.name);
							else $$ = $1;
						}
		| FL				{ 	if($1.type == UNDEFINED) yyerror($1.name);
							else $$ = $1;
						}
		| A_ID				{ 	
							CustomSymbol *sym = customSymLookup($1.name);
							if (sym == NULL) {
								yyerror("Error Semàntic: Variable not found (ID).");
							      	$$ = (variable){ .type = UNDEFINED, .place = "SEMANTIC ERROR" };
							} else {
							      	$$ = (variable){
								 	.type = sym->type,
								  	.place = strdup(sym->value),
								 	.name = strdup($1.name)
							      	};
							}
						}
		|ID				{ 	
							CustomSymbol *sym = customSymLookup($1.name);
							if (sym == NULL) {
								yyerror("Error Semàntic: Variable not found (ID).");
							      	$$ = (variable){ .type = UNDEFINED, .place = "SEMANTIC ERROR" };
							} else {
							      	$$ = (variable){
								  	.type = sym->type,
								  	.place = strdup(sym->value),
								  	.name = strdup($1.name)
							      };
							}
						}
		| LERR EOL			{ $$.type = UNDEFINED; yyerror("Error lèxic: caràcter invàlid. (LERR EOL 2)\n"); yylineno++; }
		| LERR 				{ $$.type = UNDEFINED; yyerror("Error lèxic: caràcter invàlid. (LERR 2)\n"); } 
		| error	EOL			{	$$.type = UNDEFINED;
							if (errflag == 1) errflag = 0;
							else fprintf(fInfo,"\t Error síntàctic: No hi ha cap regla que coicideixi. (error EOL 2)\n");	
							yylineno++;
						} ;
						
boolean: boolean_or;

boolean_or:
      boolean_or OR boolean_and    { $$ = generateBooleanOperation($1, "OR", $3); }
    | boolean_and                  { $$ = $1; };

boolean_and:
      boolean_and AND boolean_not  { $$ = generateBooleanOperation($1, "AND", $3); }
    | boolean_not                  { $$ = $1; };

boolean_not:
      NOT boolean_relational       { $$ = generateUnaryBooleanOperation("NOT", $2); }
    | boolean_relational           { $$ = $1; };

boolean_relational: boolean_arithmetic
	| LPAREN boolean RPAREN	{ $$ = $2; }
	| BOOL 	{ 
		$$.place = (char *)malloc(10);
		$$.type = BOOLEAN;
		strcpy($$.place, $1.place);
		if (strcmp($1.place, "TRUE") == 0) {
			$$.truelist = makelist(currQuad);
			addQuad(1, "GOTO");
		} else {
			$$.falselist = makelist(currQuad);
			addQuad(1, "GOTO");
		}
	}
	| B_ID	{	
		if(sym_lookup($1.name, &$1) == SYMTAB_NOT_FOUND) {
			yyerror("SEMANTIC ERROR: VARIABLE NOT FOUND\n");errflag = 1; YYERROR;
		}
		else { $$.type = $1.type; $$.value=$1.value; $$.place = $1.place;}
	};

boolean_arithmetic: arithmetic BOOLOP arithmetic 	{
	int aux = currQuad +1;
	$$.truelist = makelist(currQuad);
	$$.falselist = makelist(aux);
	char buffer[100];
	sprintf(buffer, $2.place);
	if ($1.type == INTEGER && $3.type == INTEGER) strcat(buffer, "I");
    	else strcat(buffer, "F");
	addQuad(5, "IF", $1.place, buffer, $3.place, "GOTO");
	addQuad(1, "GOTO");
};

%%

void yyerror(char *explanation) {
	if (strcmp(explanation, "--- FINAL DE FITXER --- Execució completada :)\n") == 0)	fprintf(fInfo,"%s", explanation);
	else 	fprintf(fInfo,"Línia %d\t%s", yylineno, explanation);
}

void addQuad(int num_args, ...) {
  va_list args;
  va_start(args, num_args);
  quad q;
  q.one = NULL;
  q.two = NULL;
  q.three = NULL;
  q.four = NULL;
  q.five = NULL;
  q.six = NULL;
  q.label = NULL;

  if (num_args > 0) {q.one = (char *)malloc(100); strcpy(q.one, va_arg(args, char*));}
  if (num_args > 1) {q.two = (char *)malloc(100); strcpy(q.two, va_arg(args, char*));}
  if (num_args > 2) {q.three = (char *)malloc(100); strcpy(q.three, va_arg(args, char*));}
  if (num_args > 3) {q.four = (char *)malloc(100); strcpy(q.four, va_arg(args, char*));}
  if (num_args > 4) {q.five = (char *)malloc(100); strcpy(q.five, va_arg(args, char*));}
  if (num_args > 5) {q.six = (char *)malloc(100); strcpy(q.six, va_arg(args, char*));}
  quad_list[currQuad] = q;
  currQuad++;
  va_end(args);
}




char *newTemp() {
  char tempString[50];
  sprintf(tempString, "$t%d", temp);
  temp++;
  char *tempPointer = tempString;
  return tempPointer;
}

variable arithmeticCalc(variable v1, char *op, variable v2) {
    	variable result = {.type = UNDEFINED};
    	result.place = (char *)malloc(100);
    
    	if(strcmp(op, "**")==0) return powFunction(v1, v2, v1.name);
    	
	// Busca els valors a la taula de símbols
	CustomSymbol *sym1 = customSymLookup(v1.place);
	CustomSymbol *sym2 = customSymLookup(v2.place);

    	if (sym1 != NULL) v1.place = sym1->value;
    	if (sym2 != NULL) v2.place = sym2->value;

    	// Tractament per a tipus enters
    	if (v1.type == INTEGER && v2.type == INTEGER) {
        	result.type = INTEGER;
        	strcpy(result.place, newTemp(NULL));

		int val1 = atoi(v1.place);
		int val2 = atoi(v2.place);
		char tempValue[50];
		if (strcmp(op, "+") == 0) {		
			addQuad(4, result.place, "ADDI", v1.place, v2.place);		// SUMA
			sprintf(tempValue, "%d", val1 + val2);
		} else if (strcmp(op, "-") == 0) {
			addQuad(4, result.place, "SUBI", v1.place, v2.place);		// RESTA
			sprintf(tempValue, "%d", val1 - val2);
		} else if (strcmp(op, "*") == 0) {
			addQuad(4, result.place, "MULI", v1.place, v2.place);		// MULT
			sprintf(tempValue, "%d", val1 * val2);
		} else if (strcmp(op, "/") == 0) {
			if (strcmp(v2.place, "0") == 0) {
				fprintf(fInfo, "ERROR: Division by zero a la línia %d\n", yylineno);
       				return (variable){ .type = UNDEFINED, .place = "SEMANTIC ERROR" };
		    	}
			addQuad(4, result.place, "DIVI", v1.place, v2.place);
		    	sprintf(tempValue, "%d", val1 / val2);				// DIV
		} else if (strcmp(op, "%") == 0) {		
			if (strcmp(v2.place, "0") == 0) {
				fprintf(fInfo, "ERROR: Modulo by zero a la línia %d\n", yylineno);
        			return (variable){ .type = UNDEFINED, .place = "SEMANTIC ERROR" }; 
			}     
			sprintf(result.place, "%d", val1 % val2);
			addQuad(4, result.place, "MODI", v1.place, v2.place);		// MOD
		}

		customSymEnter(result.place, tempValue, INTEGER);
    	} else if ((v1.type == INTEGER || v1.type == FLOAT) && (v2.type == INTEGER || v2.type == FLOAT)) {
        	result.type = FLOAT;

		float val1 = atof(v1.place);
		float val2 = atof(v2.place);
		char tempValue[50];

        	if (v1.type == INTEGER) {
			char *temp = newTemp(NULL);
			addQuad(3, temp, "I2F", v1.place);
		    	sprintf(temp, "%.2f", atof(v1.place)); // Conversió
		    	v1.place = temp;
		    	v1.type = FLOAT;
        	}
        	if (v2.type == INTEGER) {
            		char *temp = newTemp(NULL);
            		addQuad(3, temp, "I2F", v2.place);
            		sprintf(temp, "%.2f", atof(v2.place)); // Conversió
            		v2.place = temp;
            		v2.type = FLOAT;
        	}

        	strcpy(result.place, newTemp(NULL));

        	if (strcmp(op, "+") == 0) {
        		addQuad(4, result.place, "ADDF", v1.place, v2.place);
        		sprintf(tempValue, "%.2f", val1 + val2);
        	} else if (strcmp(op, "-") == 0) {
        		addQuad(4, result.place, "SUBF", v1.place, v2.place);
        		sprintf(tempValue, "%.2f", val1 - val2);
        	} else if (strcmp(op, "*") == 0) {
        		addQuad(4, result.place, "MULF", v1.place, v2.place);
        		sprintf(tempValue, "%.2f", val1 * val2);
        	} else if (strcmp(op, "/") == 0) {
           		if (atof(v2.place) == 0.0) {
				strcpy(result.place, "SEMANTIC ERROR: Division by zero");
				return result;
            		}
            		addQuad(4, result.place, "DIVF", v1.place, v2.place);
            		sprintf(tempValue, "%.2f", val1 / val2);
        	}

        	customSymEnter(result.place, tempValue, FLOAT);
	} else {
		result.type = UNDEFINED;
		strcpy(result.place, "SEMANTIC ERROR: Invalid operation");
    	}
    	return result;
}

long potenciaRecursiva(long base, long exponent) {
	if (exponent == 0) return 1;
    	else return base * potenciaRecursiva(base, exponent - 1);
}

variable powFunction(variable v1, variable v2, char* assign_name) {
    	variable result;
    	result.place = (char *)malloc(100);

    	if (v2.type != INTEGER) {
        	result.type = UNDEFINED;
        	strcpy(result.place, "SEMANTIC ERROR: L'exponent ha de ser enter.");
        	return result;
    	}

    	long base = atol(v1.place);
    	long exponent = atol(v2.place);

    	if (exponent < 0) {
        	result.type = UNDEFINED;
        	strcpy(result.place, "SEMANTIC ERROR: Exponent negatiu no suportat.");
        	return result;
    	}

    	long result_value = potenciaRecursiva(base, exponent); // Calcula la potència

	result.type = v1.type;
    	sprintf(result.place, "%ld", result_value);

    	addQuad(4, assign_name, "POWI", v1.place, v2.place);

    	customSymEnter(assign_name, result.place, result.type);

    	return result;
}



void printQuads(){
	fprintf(fInfo, "Line %d, Printing intermediate code\n", yylineno);
	
	if (currQuad == 0) {
  		printf("quad_list is empty\n");
  		return;
	}
	int i;
	for (i= 0; i < currQuad; i++) {
   		quad *q = &quad_list[i];
   		char aux[500];
   		if (q->one != NULL)		sprintf(aux, q->one);
   		if (q->two != NULL)		{strcat(aux, " "); strcat(aux, q->two);}
   		if (q->three != NULL)	{strcat(aux, " "); strcat(aux, q->three);}
   		if (q->four != NULL)	{strcat(aux, " "); strcat(aux, q->four);}
   		if (q->five != NULL)	{strcat(aux, " "); strcat(aux, q->five);}
   		if (q->six != NULL)		{strcat(aux, " "); strcat(aux, q->six);}
   		if (q->label != NULL)	{strcat(aux, " "); strcat(aux, q->label);}
   		strcat(aux, "\0");
   		printf("%d: %s\n", i+1, aux);
	}

	printf("%d: HALT\n", i+1);
	
}


void customSymEnter(char *name, char *value, int type) {
	
	// Comprova si és una variable temporal i la ignora
	if (name[0] == '$' && strstr(name, "_t") != NULL) {
		return; // No afegir temporals
	}
	
	for (int i = 0; i < customSymtabCount; i++) {
        	if (strcmp(customSymtab[i].name, name) == 0) {
            		free(customSymtab[i].value);
            		customSymtab[i].value = strdup(value);
			customSymtab[i].type = type;
			
            		// Detecta si el nom té un prefix associat a una taula i ajusta el tipus
            		/*if (type == INTEGER && strstr(name, "_t") != NULL)	customSymtab[i].type = ARRAY;
            		else customSymtab[i].type = type;*/
            		return;
        	}
    	}

    	if (customSymtabCount < CUSTOM_MAX_SYMBOLS) {
        	customSymtab[customSymtabCount].name = strdup(name);
        	customSymtab[customSymtabCount].value = strdup(value);
		customSymtab[customSymtabCount].type = type;
		
		// Detecta si el nom té un prefix associat a una taula i ajusta el tipus
		/*if (type == INTEGER && strstr(name, "_t") != NULL) {
		    customSymtab[customSymtabCount].type = ARRAY;
		} else {
		    customSymtab[customSymtabCount].type = type;
		}*/

        	customSymtabCount++;
	} else {
		printf("Error: Taula de símbols plena!\n");
	}
}

CustomSymbol *customSymLookup(char *name) {
	for (int i = 0; i < customSymtabCount; i++) {
        	if (strcmp(customSymtab[i].name, name) == 0)	return &customSymtab[i];
    	}
    	return NULL;
}

void mostrarCustomSymtab() {
    fprintf(fInfo, "Mostrant la taula de símbols personalitzada:\n");
    for (int i = 0; i < customSymtabCount; i++) {
        fprintf(fInfo, "Variable %s:\n\t->Valor: %s\n\t->Tipus: %s\n",
       customSymtab[i].name,
       customSymtab[i].value,
       customSymtab[i].type == INTEGER ? "INTEGER" :
       customSymtab[i].type == FLOAT ? "FLOAT" :
       customSymtab[i].type == BOOLEAN ? "BOOLEAN" :
       customSymtab[i].type == ARRAY ? "ARRAY" : "UNDEFINED");
    }
}


list* makelist(int i){
	list *pointer = malloc(sizeof(list));
	pointer->next = NULL;
	pointer->index = i;
	return pointer;
}

list* merge(list *l1, list *l2){
	list *comb;
	
	if (l1 == NULL) comb = l2;
	else {
		comb = l1;
		while (comb->next != NULL){
			comb = comb->next;
		}
		if (l2 != NULL) comb->next = l2;
	}
	
	return comb;
}

void backpatch(list *p, int l){
	char * label = malloc(sizeof(char)*100+1);
	sprintf(label, "%d", l);
	while(p != NULL){
		quad_list[p->index].label = malloc(sizeof(char)*100+1);
		strcpy(quad_list[p->index].label , label);
		p = p->next;
	}

}

variable generateBooleanOperation(variable v1, char *op, variable v2) {
    variable result;
    result.type = BOOLEAN;
    result.place = newTemp(NULL); // Temporal per guardar el resultat

    // Obtenim els valors reals de les variables
    CustomSymbol *sym1 = customSymLookup(v1.place);
    CustomSymbol *sym2 = customSymLookup(v2.place);

    char *val1 = sym1 ? sym1->value : v1.place;
    char *val2 = sym2 ? sym2->value : v2.place;

    // Calcula el resultat
    char *booleanValue = (char *)malloc(6);
    if (strcmp(op, "AND") == 0) {
        sprintf(booleanValue, "%s", (strcmp(val1, "TRUE") == 0 && strcmp(val2, "TRUE") == 0) ? "TRUE" : "FALSE");
    } else if (strcmp(op, "OR") == 0) {
        sprintf(booleanValue, "%s", (strcmp(val1, "TRUE") == 0 || strcmp(val2, "TRUE") == 0) ? "TRUE" : "FALSE");
    }

    // Guarda el resultat a la taula de símbols
    customSymEnter(result.place, booleanValue, BOOLEAN);

    // Genera el quad i actualitza el comptador de línia
    addQuad(4, result.place, op, v1.place, v2.place);
    fprintf(fInfo, "DEBUG: Boolean operation %s %s %s = %s\n", val1, op, val2, booleanValue);

    return result;
}

variable generateUnaryBooleanOperation(char *op, variable v) {
    variable result;
    result.type = BOOLEAN;
    result.place = newTemp(NULL); // Temporal per guardar el resultat

    // Obtenim el valor real de la variable
    CustomSymbol *sym = customSymLookup(v.place);
    char *val = sym ? sym->value : v.place;

    // Calcula el resultat
    char *booleanValue = (char *)malloc(6);
    sprintf(booleanValue, "%s", (strcmp(val, "TRUE") == 0) ? "FALSE" : "TRUE");

    // Guarda el resultat a la taula de símbols
    customSymEnter(result.place, booleanValue, BOOLEAN);

    // Genera el quad
    addQuad(3, result.place, op, v.place);
    fprintf(fInfo, "DEBUG: Unary boolean operation %s %s = %s\n", op, val, booleanValue);

    return result;
}



int main(int argc, char** argv) {
    fInfo = fopen("sortida_proves.txt", "w");
    if(fInfo == NULL){
        printf("Error: Unable to open log file fInfo.txt\n");
        return 1;
    }

    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (yyin == NULL) {
            printf("Error: Unable to open file %s\n", argv[1]);
            return 1;
        }
    }
    else {
        printf("Error: No input file specified\n");
        return 1;
    }
    
    quad_list = (quad *)malloc(sizeof(quad) * MAX_QUADS);
    yyparse();
    printQuads();
    mostrarCustomSymtab();
    free(quad_list);
    if(fclose(fInfo) != 0){
        printf("Error: Unable to close log file log.txt\n");
        return 1;
    }

    return 0;
}
