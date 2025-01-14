#import "Parameters"
#import <database>
/* This file is part of niqlow. Copyright (C) 2012-2023 Christopher Ferrall */

/** Tags for Gradient-based optimization algorithms.	@name QuasiAlgorithms**/	
enum{USEBHHH,USEBFGS,USEDFP,USESTEEP,USENEWTON,QuasiAlgorithms}

/** Tags weighting options.	@name MixedWeightOptions **/	
enum{EqualInitialWeights,SimplexWeights,FixedWeights,MixedWeightOptions}

/** Base class for objective optimization and system solving.

**/
struct Objective	{
	static 	const	decl
	/**Extension for `Objective::Load` and
		`Objective::Save` files, =<q>optobj</q>.	**/			EXT	= "optobj",
		    													dStepLinearGap = 1e-10;

	const	decl 	
	/** label.     **/            								L,
	/** current point.**/										vcur,
	/** Name for `Objective::Load` &amp; files	**/				fname,
    /** name of log file **/                                    lognm,
	/** Best so far @see Objective::CheckMax    **/ 			maxpt,
	/** . @internal**/											hold;

	static decl
    /** Version of niqlow that code is written for.
        @see Objective::SetVersion **/                          MyVersion,
	/** . internal **/											Warned;
	decl
    /** log file **/                                            logf,
    /** Set in CheckMax(), TRUE if latest check was new max.**/ newmax,
    /** This objective uses raw parameter values. **/           DoNotConstrain,
    /** TRUE when computing Gradient, can be used by semi-closed
        form gradient methods.**/                               INGRADIENT,
    /** TRUE (default): exit if NaNs encountered during iteration<br>
            FALSE: exit with <code>IterationFailed</code> **/
                                                                RunSafe,
	/** P2P object for using MPI across param vectors**/	    p2p,
    /** P2P object for MPI on a single param vector.**/         subp2p,
	/** Initial vector after Encode() **/						Start,
	/** TRUE if encoded once **/								once,
	/** User-defined subvectors of parameters. @internal**/		Blocks,
    /** holds DoNotVary vector for temp. 1-d solution.**/       fshold,
	/** array of all parameter objects. @internal       **/		Psi,
	/** all parameter labels **/								PsiL,
	/** parameter class names **/								PsiType,
	/** Longest vector returned by vfunc(), default=1.**/ 		NvfuncTerms,
	/** Output Level.**/ 										Volume,
	/** array free parameter labels **/							Flabels,
	/** length of F in current cycle.     **/					nfree,
	/** length of X.     					 **/				nstruct,
	/** vector of F indices into X. @internal   **/				FinX;

            virtual ResetMax();
			Objective(L="",CreateCur=TRUE);
			Save(fname=0);
			Load(fname=0);
			SetAggregation(AggType);
            CheckMaxV(v,fn);

	static 	dFiniteDiff0(x);
	static 	dFiniteDiff1(x);
	static 	dFiniteDiff2(x);
    static  SetVersion(v=350);

	        ToggleParameterConstraint();
            FreeStatus(Store=TRUE);
    virtual Recode(HardCode=FALSE);
	virtual	ToggleParams(...);
    virtual ToggleBlockElements(pblock,elements=DoAll);
	virtual	CheckMax(fn=0);
	virtual Print(orig,fn=0,toscreen=TRUE);
	virtual	CheckPoint(f,saving);
	virtual Parameters(...);			
	virtual Block(B);
	virtual Gradient(extcall=TRUE);
	virtual Jacobian();
    virtual Hessian();
	virtual vfunc(subp=DoAll);
	virtual fobj(F=0,extcall=TRUE);
	virtual vobj(F=0);
	virtual	Encode(X=0);
	virtual	Decode(F=0);
    virtual ReInitialize();
	virtual funclist(Xmat,Fvec,afvec=0,abest=0);
    virtual Menu();
    virtual Interact();
    virtual contour(Npts,Xpar,Ypar,lims);
    virtual AggSubProbMat(submat);
	}

	
/** Container for Unconstrained Objectives.
**/
struct UnConstrained : Objective {
	virtual Gradient(extcall=TRUE);
			UnConstrained(L="");
	}
	
/** Container for Constrained Objectives.

**/	
struct Constrained : Objective {
			Constrained(L,ELorN,IELorN);
			Lagrangian(F);
			funclist(Fmat,jake);
	virtual	CheckPoint(f, saving);
	virtual	Jacobian();
	virtual	Gradient(extcall=TRUE);
	virtual equality();
	virtual	inequality();
	virtual Merit(F);
	}


/** A non-linear system of equations to solve.
**/
struct System : Objective {
	decl
    /**1 equation of system.**/     eq1,
	/** . @internal **/		        eqn,
                                    normexp;
			System(L,LorN=1,incur=0);
    virtual SetOneDim(isys=0,ipar=0);
            EndOneDim();
	virtual equations();
	//virtual fobj(F,extcall=TRUE);
	}

/** A nonlinear system for computing equilibrium.
This provides a framework for equilibrium prices in a model with an aggregate production function.
<DT>$T$ periods (default $T=1$)</DT>
<DT>Production</DT>
<DD>A $N\times 1$ vector $X.$</DD>
<DD>$F(X^d)$ is aggregate output where $X^s$ stands for aggregate demand.</dd>
<dd>$p_t$ is a $n\times 1$ price vector in period $t$.</DD>
<DD>The respresentative firm acts to maximize static profit by choosing $X^d_$ accounting for input prices and a
depreciation vector $\Delta$.  First order conditions at $t$ are:
$$\nabla F(X^d_t)^\prime - \Delta - p_t = \overrightarrow{0}$$
where $\nabla F$ is the $1\times N$ gradient of the production function with respect to $X^d_t$.</DD>
<DT>Households</DT>
<DD>Consumer behavior is described by a DP with $T$ periods.  If the clock is ergodic then it is a stationary equilibrium
for infinitely lived agents.  If the clock is non-stationary then it is a sequence of $T$ static equilibrium problems
which are connected because agent behavior at $t$ depends on future prices and past choices through
the current distribution across states.  (This version does not handle overlapping generations.)</DD>
<DD>Adding variables to $\gamma_r$  (random effects) allows for heterogeneity.  (This version does not allow fixed effects.)</DD>
<DD>The price matrix $p$ enters $U()$, usually through a budget constraint that determines consumption.</DD>
<DD>Quantities of per-capita values supplied by households ($X^s$) are determined by the predicted amounts :
$$X^s_t = \sum_{\gamma_r}g(r)\left[ \sum_{\theta\in\Theta} f_t(\theta;\gamma_r) x_t(\theta;\gamma_r)\right].$$
Here $x_t(\theta;\gamma_r)$ is the vector of elements of of the DP outcome $Y$ that match up to the
factors of production.  $f_t$ is the distribution over states at $t.$  The user specifies the intial
distribution $f_0$.  If the equilibrium is stationary then this is the ergodic distribution $f_\infty$.
<details class="aside">A fixed factor can be included by adding a constant <code>AuxiliaryOutcome</code> to
to the DP, which would then always average across states and household types to the fixed factor.</details>
</DD>
<DD>In other words, $X^s_t$ are computed from the  <code>PathPrediction</code> of length $T$ starting from exogenous
initial conditions.</DD>
<DT>Equilibrium</DT>
<DD>In equilibrium the price vector $p^\star_t$ satisfies the first order conditions when $X^s$ is inserted for $X^d$ at
each $t.$  </DD>
<DD>In general, the full price vector $p^\star$ is the solution to a system of $TN$ equations.  Depending on the production fucntion
$f(X)$ some of the equations may be solved out to reduce the number of equations.  In that case some elements
of $p^\star$ are `Determined` parameters not available for the system algorithm to vary.</DD>
**/
struct Equilibrium : System {
    const decl
        /** number of periods in equilibrium. **/               T,
        /** list of aggregate prod. function `BlackBox`.**/     aggF,
        /** ergodic distribution `PathPrediction`.**/           stnpred,
        /** 0.0 or vector of quantity depreciations.**/         deprec,
        /** columns of pred that match up to inputs.**/         Qcols;

    decl
         /** computed system.**/                        foc,
        /** aggregate Qs from prediction.**/            Q;

               Equilibrium(L,T=One,P=0);
	           Print(orig,fn=0,toscreen=TRUE);
    virtual    vfunc();
    }


/* Create a system for con
struct FOC : System {
    }
*/

/** A One Dimensional Non-linear system (can be solved with `OneDimSolve`).
**/
struct OneDimSystem : System {
    const decl  msys;
    decl
                isys,
                ipar;
	
            OneDimSystem(L,msys=0);
            SetOneDim(insys=0,inpar=0);
            CheckMax(fn=0);
            ResetMax();
    virtual vfunc();
	}

/** Represents a blacbox objective.

This is the container class for a standard function to maximize.

A BlackBox has no internal structure (such as separability of parameters).

**/
struct BlackBox : UnConstrained	{
	BlackBox(L);
	}

/** Cobb-Douglas objective.
$$f = A \prod_{i=0}^{N^-} x_i ^{\alpha_i}.$$

$A$ and $\alpha$ are `CV`-compatible objects.
**/
struct CobbDouglas : BlackBox {
    decl    x, alphas, A;
            CobbDouglas(L,alphas=<0.5;0.5>,A=1.0,labels=0);
    virtual vfunc();
    virtual AnalyticGradient();
    }	


/** Constant elasticity of subsitution function.
**/
struct CES : BlackBox {
    decl    x, elast, alphas, A, xpon;
            CES(L,alphas=<0.5;0.5>,elast=-2.0,A=1.0,labels=0);
    virtual vfunc();
    }	


/**Base class for automatically generated econometric objectives: likelihood functions and GMM objective.

This objective takes a "data" object that is typically either a `OutcomeDataSet` or a
`PredictionDataSet`.

**/
struct DataObjective : BlackBox {
	const decl
        /** path or prediction object.**/   data;
    decl
        /** transition parameters .**/      tplist,
        /** utility parameters .**/         uplist,
        /** estimation stage.**/            stage;
	
            DataObjective(L,data,...);
	virtual vfunc(subp=DoAll);
    virtual AggSubProbMat(submat);
	        TwoStage(tplist,uplist);
            SetStage(stage);
	}



/* An objective to represent a continuous choice at a point in the state space of a dynamic program.

The purpose of this objective is to make it easier for the model to include a static optimization
problems at each state (and each discrete choice $\alpha$).

@example
    struct Effort : CondContChoice {
        decl x;
        vfunc();
        }

    Effort::vfunc() {
        v = -sqr(CV(x)) + ;
        }

    MyModel::Initialize() {
        x = new Positive("x",0.5);
        }

    MyModel::Utility() {

        }
    </DD>

struct CondContChoice : BlackBox {
    decl algor, theta, arow, Aoptvals, Aobj;
    CondContChoice(L);
    SetAlgorithm(algor);
    AtTheta(theta);
    }
*/

struct NoObjective : BlackBox {
    decl model,v,modelmethod;
    NoObjective(model);
    vfunc(subp=DoAll);
    }

/** Objective for multinomial choice models.
**/
struct MultiNomialChoice : BlackBox {
	const 	decl
	/** indexing vector           **/    NN,
	/** J : number of options     **/    J,
	/** K : number of X variables **/    nX,
	/** integer codes of choices  **/    Jvals,
	/** X : matrix of exog variables**/  X,
	/** Y : discrete endog vector **/    Y,
	/** N x J matrix of permutations<br>
		the first column is index of Y<br>
		second column is first non-Y choice<br>
		third column is second non-Y choice<br>etc.
									**/  indY,
	/** Labels for variables **/		 namearray,
	/** Array of J-1 parameter blocks, one
	for each equation except Y=0.**/   	betas;
    decl
    /** matrix of XB indices.**/                D,
    /** vector or matrix of likelihods.**/      lk;
	MultiNomialChoice(L,fn,Y,Xvars);
    SetD();
    Estimate();
	}

/** Container for normally-distributed multinomial discrete choice reduced-form models.**/
struct MNP : MultiNomialChoice {
    }

/** Multinomial Logit Model. **/
struct MLogit : MultiNomialChoice {
	MLogit(L,fn,Y,Xvars);
    vfunc();
    }

/** Independent MNP using Gausss-Hermite integration.**/
struct GQMNP : MNP {
	const	decl
    /** # of nodes in quadrature **/ 	Npts;
	GQMNP(L,fn,Yname,Xnames,Npts)	;
	vfunc();
	}

/** Correlated MNP using GHK . **/
struct GHKMNP : MNP {
	enum{identity,onlydiag,lowertriangle,SigmaOptions}
    const decl
	/** **/			           ghk,
	/** **/			           SigLT,
	/** **/			           sigfree;
	GHKMNP(L,fn,Yname,Xnames,R,iSigma);
	SetGHK(R,iseed);
	vfunc();
    }

/** Represent sum of <var>K</var> `BlackBox` objectives. **/
struct Separable : UnConstrained	{
	const 	decl
														scur,
	/** # unobserved types, sub-problems **/  			K,
	/** `Discrete` sub-problem var **/					Kvar,
	/** labels for types / sub problems**/				KL;
	
	decl
	/** Number of common parameters **/ 				C,
	/** Total free parameters **/   					nfree,
	/** Vector of indices into Psi of common pars **/	ComInd,
	/** K Vector of free specific parameters **/		kfree,
														Included,
	/** Longest vector returned by vfunc(), default=1.**/ NvfuncTerms,
														kNvf,
														CDNV,
	/** . @internal **/									Start,
	/** . @internal **/									FinX,
	/** . **/											Flabels;
	
			Separable(L,Kvar);
			kEncode(notmulti);
	virtual	Deconstruct(eval) ;
			ResetCommon(hold);
	virtual Print(orig,fn=0,toscreen=TRUE);
//	virtual	CheckPoint(f,saving);
    virtual	CheckMax(fn=0);
	virtual	Common(... );	
	virtual vfunc();						   			
	virtual fobj(F,extcall=TRUE);
	virtual vobj(F);
	virtual	Encode(X=0,CallBase=FALSE);
	virtual	Decode(F=0);
	virtual Jacobian();
	virtual	Gradient(extcall=TRUE);
	virtual funclist(Xmat,aFvec,afvec=0);
	}

struct Mixture : Separable {
	const 	decl
														mcur,
	/** # observed types, environment **/  				D,
	/** D x K **/										DK,
	/** `Discrete` environment-type var **/				Dvar,
														DKL;
	decl
	/** array of weight objects. @internal**/			Lambda,
	/**									   **/			WStart,
	/** matrix of indicators of valid d,k combos **/	Included,
														FinL,
														Flabels,
														lfree,
                                                        nfree,
	/** **/												dkfree;
	
			Mixture(L,Dvar,Kvar,MixType,...);
			WDecode(WF);
			WEncode(inW);
			IncludedDK(mDK);
			Print(orig,fn=0,toscreen=TRUE);
	virtual	vfunc();
    virtual	CheckMax(fn=0);
			fobj(f,extcall=TRUE);
	virtual	Deconstruct(eval) ;
	virtual vobj(F);
	virtual	Decode(F=0);
	virtual	Encode(X=0);
	virtual Jacobian();	
	virtual	Gradient();
	virtual funclist(Fmat,aFvec);
	virtual Wfunclist(Lmat,aFvec);
	}
	
