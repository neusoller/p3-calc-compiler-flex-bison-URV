#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>




#ifndef VARIABLE_TYPE
#define VARIABLE_TYPE
typedef enum
{
    INTEGER,
    FLOAT,
    STRING,
    BOOLEAN,
    UNDEFINED,
    ARRAY
} varType;

typedef struct list_t
{
    int index;
    struct list_t *next;
} list;

typedef struct variable_t
{
    char * name;
    varType type;
    char * place;
    char * ctr;
    int repeat;

    char * value;
    list * truelist;
    list * falselist;
    list * nextlist; 
} variable;


typedef struct quad_t
{
    char * one; //resultat o primer parametre a emetre
    char * two; //primera variable
    char * three; //operand
    char * four;    //segona variable
    char * five;    //segona variable
    char * six;    //segona variable
    char * label;

} quad;

typedef struct switchL{
    int instr;     /**Instruction number*/
    int lineno;    /**Line number where this list was found*/
    struct switchL *next; /**Next pointer of switch list*/
    bool stype;    /**default or case statement*/
    char *val;     /**Case value*/
  }switchL;

typedef struct {
    char *name;   // Nom de la variable
    char *value;  // Valor de la variable com a cadena
    int type;     // Tipus de variable: 0 = INTEGER, 1 = FLOAT
} CustomSymbol;


#endif
