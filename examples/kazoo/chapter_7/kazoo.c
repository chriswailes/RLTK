#include <stdio.h>

/* putchard - putchar that takes a double and returns 0. */
double putchard(double x) {
	putchar((char) x);
	return 0;
}

double putd(double x) {
	printf("%f\n", x);
	return 0;
}
