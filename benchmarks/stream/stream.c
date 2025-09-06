#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define ARRAY_SIZE 1000000  // Tableau de 1 million d'éléments (environ 4 MB)
#define ITERATIONS 100      // 100 itérations pour un workload léger

int main() {
    double *a = (double *)malloc(ARRAY_SIZE * sizeof(double));
    double *b = (double *)malloc(ARRAY_SIZE * sizeof(double));
    double *c = (double *)malloc(ARRAY_SIZE * sizeof(double));
    clock_t start, end;
    double time_spent;

    if (a == NULL || b == NULL || c == NULL) {
        printf("Memory allocation failed\n");
        return 1;
    }

    // Initialisation
    for (int i = 0; i < ARRAY_SIZE; i++) {
        a[i] = 1.0;
        b[i] = 2.0;
    }

    // Mesure du temps pour le workload (simplifié Stream triad: a = b + c)
    start = clock();
    for (int j = 0; j < ITERATIONS; j++) {
        for (int i = 0; i < ARRAY_SIZE; i++) {
            a[i] = b[i] + c[i];
        }
    }
    end = clock();
    time_spent = (double)(end - start) / CLOCKS_PER_SEC;

    printf("Stream ready - Execution time: %.3f seconds\n", time_spent);
    free(a);
    free(b);
    free(c);
    return 0;
}