/* This file is part of niqlow. Copyright (C) 2018 Christopher Ferrall */
#import "Bellman"

/** Tags for Nonlinear System Solver Algorithms. @name SystemAlgorithms **/	
enum{USEBROYDEN,USENEWTONRAPHSON,SystemAlgorithms}

/** A container for solution methods.    **/
struct Method : FETask {
	   static const decl
		/** Default convergence tolerance on Bellman Iteration for stationary
            environments = `DIFF_EPS` = 10^{-8}. @see Method::Tune , Clock::normparam
            **/                                                     DefTolerance = DIFF_EPS;
        decl
        /** Either r or AllRan to solve for all random effects.**/  Rgroups,
        /** FALSE(default): iterate on V(&theta;)<br>
            TRUE: only compute transitions.
            @see Method::ToggleIterate **/                         DoNotIterate,
                                                                    vtoler,
    /** Output from the solution method.  Passed on to `GSolve::Volume`.
        @see NoiseLevels**/                                         Volume;
    Method(GSolve=0);
    Initialize(MaxTrips=UseCurrent);
    ToggleRunSafe();
    ToggleIterate(ToggleOnlyTrans=TRUE);
    virtual Run();
    virtual Solve(Fgroups=AllFixed,Rgroups=AllRand);
    virtual Tune(Volume=UseCurrent,vtoler=UseCurrent,MaxTrips=UseCurrent,NormType=UseCurrent);
	}

/**	Loop over random effect values $\gamma_r$, call  GSolve() method for the calling method.
**/
struct RandomSolve : RETask {
    decl retval;
    RandomSolve(gtask,mycaller=UnInitialized);
    Run();
    }

/** The base method for iterating over $\theta$ during solution methods.
    Some methods provide a replacement for this.
**/
struct GSolve : ThetaTask {
    decl
     /** . @internal**/                                     dff,
    /** TRUE (default): exit if NaNs encountered during iteration<br/>
        FALSE: exit with <code>IterationFailed</code> **/    RunSafe,
    /** TRUE if all tasks suceed.**/                        succeed,
    /** . @internal**/                                      warned,
    /** Amount of ouptut to produce @see NoiseLevels**/     Volume,
    /** Fixed limit on number of iterations.**/             MaxTrips,
    /** Flag set if extra loop after converging,
        e.g. when computing semi-closed-form derivatives.**/ AuxRun,
	/** Tolerance on value function convergence in stationary
        environments.  Default=`Method::DefTolerance`.**/   vtoler;

            ZeroTprime();
            GSolve(caller=UnInitialized);
            Report(mefail);
    virtual Solve(instate);
    virtual Run();
	virtual Update();
    virtual PostEMax();
    virtual AuxiliaryRun(instate);
	}

#ifdef OX_PARALLEL
#ifndef Mh
    #define Mh
    #include "ValueIteration.h"
    #include "HotzMiller.h"
    #include "SolveAsSystem.h"
    #include "ReservationValues.h"
    #include "ImaiJainChing.h"
#endif
#endif
