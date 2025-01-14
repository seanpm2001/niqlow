/** Optimization using FiveO <a href="FiveO/default.html">documentation</a>.
**/
#include "examples.h"
#include "GetStartedFiveO.ox"

/**Create a menu for choosing examples, called from examples/main. **/
FiveOmenu() {
    decl mm = new CallMenu("FiveO Tests and Demos",TRUE,FALSE);
    mm -> add(
			{"Get Started w/ Opimization",GS5OA},
			{"Get Started w/ NL Systems",GS5OB},
			{"All Tests ", 		OptTestRun()      });
    return mm;
    }
