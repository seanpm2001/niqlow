#include "DP.h"
/* This file is part of niqlow. Copyright (C) 2011-2023 Christopher Ferrall */


/** Called by CreateSpaces.
@internal
**/
I::Initialize() {
    decl i;
    OO=zeros(1,N::S);
	for(i=LeftSV;i<DSubSpaces;++i) OO |= DP::SS[i].O;
	all = new matrix[rows(OO)][1];
   	MxEndogInd = DP::SS[onlyendog].size-1;
	decl lo = DP::SS[bothexog].left, hi = DP::SS[bothexog].right;	
//	MedianExogState= (N::All[lo:hi]-1)/2;
//  July 2018.  changed so first is always median
	MedianExogState= zeros(hi-lo+1,1);
	MESind = OO[bothexog][lo:hi]*MedianExogState;
	MSemiEind = OO[onlysemiexog][lo:hi]*MedianExogState;
    majt = subt = Zero;
    elo = ehi = 0;
    }

/** Sets and stores all the state indices, called by `Task::loop` and anything else that directly sets the state.
@param state current state vector
@param group TRUE if the group indices should be set as well.
@return TRUE if the current point exists (is reachable)
@internal
**/
I::Set(state,group) {
    decl exists;
	all[] = OO*state;
    curth = Theta[all[tracking]];
    exists = !isint(curth);
    Alpha::SetA( exists ? UseCurrent : NoMatch  );
    if (group) SetGroup();
    return exists;
    }

/** Set the current group.
@param GorSV UseCurrent [default] all[bothgroup] already set
    <br/>Other integer: set all[bothgroup]
    <br/>state vector: set groupoffs using I::OO
Not usually called from user code.
@return pointer to group in the group space.

**/
I::SetGroup(GorSV) {
    if ( ismatrix(GorSV) )
        all[bothgroup] = I::OO[groupoffs][]*GorSV;  //was all[grouoffs]!!!
    else if ( GorSV!=UseCurrent ) all[bothgroup] = GorSV;
    g = int(all[bothgroup]);
    if ((isclass(curg = Gamma[g]))) {
	   f = all[onlyfixed] = curg.find;
	   r = all[onlyrand] = curg.rind;
       rtran = .NaN; // This put here to catch errors if rtran used and not working
	   curg->Sync();
	   curg->Density();
      }
    return curg;
    }
/** .
@internal
**/
I::SetExogOnly(state) {
	all[exogoffs] = OO[exogoffs][]*state;
    }

/** Tracks information about a subvector of the state vector. **/
Space::Space() {D=0; C=N=<>;   X = M= size = 1; }

/** Tracks information about a set of one or more `Space`s.**/
SubSpace::SubSpace() {D=0; size=1; O=<>;}
SubSpace::~SubSpace() { delete O; left=right=0; }

/** Calculate dimensions of a subspace.
@internal
@param subs index of subvectors of S to include in the subspace
@param IsIterating if the clock is included, use the rightmost variable in the index or set offset to 0<br>[default=TRUE]
@param FullDim


**/
SubSpace::Dimensions(subs,IsIterating,FullDim)	{
	decl k,s,v,Nsubs = sizerc(subs),nxtO,mxd;
	O = S[subs[0]].M ? zeros(1,S[subs[0]].M) : <>;  // states to the left get 0 offset
	nxtO = 1;
	left = columns(O);             // leftmost state variable index in the subspace.
	for (k=subs[0],s=0; k<=subs[Nsubs-1]; ++k)
		if (subs[s]==k)	{
			if (subs>0 && k==ClockIndex) {
				++D;				  // only one clock variable is tracked
				size *= S[k].N[IsIterating];  //track tprime if iterating, otherwise t
				O ~= IsIterating ? 0~nxtO : nxtO~0;
				nxtO *= S[k].N[IsIterating] ;
				}
			else if ( k!=rgroup || FullDim ){  //this was wrong until April 2016
				D += mxd = S[k].D;
				size *= S[k].size;
				O ~= nxtO;
				if (mxd>1) O ~= nxtO * S[k].C[:mxd-2];
				nxtO *= S[k].C[mxd-1] ;
				}
            else {  // separate transitions when random effects affect transitions
				D += mxd = S[k].D;
				size = 1;
				O ~= 0;
				if (mxd>1) O ~= 0;
                }
			++s;
			}
		else
			O ~= zeros(1,S[k].D);
	right = columns(O)-1;        //rightmost index of variables in the index
	O = shape(O,1,N::S);         // states to the right get 0 offset.
	}

/** Calculate dimensions of action space, &Alpha;.
@internal
@comments O is a column vector because it is for post-multiplying A.


**/
SubSpace::ActDimensions()	{
	left = 0;
	D = S[0].D;
	size = S[0].size;
	O = <1>;
	if (D>1) O |= S[0].C[:D-2]';
	right = rows(O)-1;
	}

/** Reset a group.
This resets `Group::Ptrans`[&Rho;(&theta;&prime;;&theta;)] and it synch &gamma;
@param gam , &gamma; group to reset.
@return density of the the group.
@see I::SetGroup
**/
Group::Reset() {
	if (Flags::IsErgodic) Ptrans[][] = 0.0;
	Sync();
	return Density();	
	}

/** Checks the version number you send with the current version of niqlow.
@param v integer [default=200]
**/
DP::SetVersion(v) {
    MyVersion = v;
    if (!Version::MPIserver) {
        if (MyVersion<Version::version)
            oxwarning("DP Warning ??. \n Your DP model is set at version "+sprint(v)+".\n You are running on a newer niqlow version, "+sprint(Version::version)+".\n");
        else if (MyVersion>Version::version)
            oxwarning("DP Warning ??. \n Your DP model is set at version "+sprint(v)+".\n You are running on an older niqlow version, "+sprint(Version::version)+".\n You should consider installing a newer release.\n");
        }
    }
	
/** Draw &gamma; from &Gamma; according to the density.
Sets <code>I::g</code> and syncs state variables in &gamma;
@return &Gamma;[gind], for external access to &Gamma;
@see DrawOne **/
DP::DrawGroup(find) {
    return I::SetGroup(N::R*find + DrawOne(gdist[find][]));	//November 2019: added N::R  and I::
    }

/** Return $P_\infty(\theta)$.
@param g group index<br/>UseCurrent (default)
@return Stationary Distribution **/
DP::GetPinf(g) {
    return (g==UseCurrent) ? I::curg.Pinfinity : Gamma[g].Pinfinity;
    }

/** Draw a population count random sample of N values from the random effects distribution.
@param find index of fixed group
@param N number of draws to take
@return 1xF vector of integer counts that sum to N
@see DP::DrawGroup
**/
DP::DrawFsamp(find,N) {
    decl ss = ranmultinomial(N,gdist[find][]);
    return ss;
    }

/**  Draw one $\epsilon$ vector given following $P(\epsilon)$.
@param aState address of state vector to insert value
@return index of the simulated $\epsilon$
**/
DP::DrawOneExogenous(aState) {
	decl i = DrawOne(NxtExog[Qprob]);
	aState[0] += ReverseState(NxtExog[Qind][i],bothexog);
	return i;
	}

/** Sets the current &theta;.
@param endogind  tracking index of the state &theta;.
@return TRUE if &theta; is reachable. FALSE otherwise.
@see I::curth
**/	
DP::Settheta(endogind) { return isclass(I::curth = Theta[endogind]); }

/** Return index into the feasible A list for a &theta;.
@param i index of &theta; in the state space &Theta;
@return &theta;.j  (Theta[i].Aind)
**/
DP::GetAind(i) {return isclass(Theta[i]) ? Theta[i].Aind : NoMatch; }

/** Return choice probability for a $\theta$ and current $\gamma$.
@param i tracking index of $\theta$ in the state space $\Theta$
@return $P*(\alpha;\epsilon,\eta,\theta,\gamma)$  (<code>Theta[i].pandv</code>)
**/
DP::GetPstar(i) {    return Theta[i].pandv;    }
DP::GetUseEps(i) {    return Theta[i]->UseEps();    }

/** Return tracking transition at a given $\eta,\theta$ combination.
@param i index of $\theta$ in the state space $\Theta$
@param h index of current $\eta$ vector
@return  $P(\theta^\prime | \alpha,\eta,\theta)$ as an array<br>
First element is vector of indices for feasible states $\theta^\prime$<br>
Second element is a matrix of transition probabilities (rows for actions $\alpha$, columns correspond to $\theta^\prime$)
**/
DP::GetTrackTrans(i,h) {
    return {Theta[i].Nxt[Qtr][h],Theta[i].Nxt[Qrho][h]};
    }

/** Ask to store overall $P*()$ choice probability matrix.
@comment Can only be called before calling `DP::CreateSpaces`
**/
DP::StorePalpha() {
	if (Flags::ThetaCreated) oxrunerror("DDP Error 35. Must be called before CreateSpaces");
	Flags::StorePA = TRUE;
	}

/** Add state variables or blocks to a subvector of the overall state vector.
@internal

@param SubV	the subvector to add to. see `SubVectorNames`
@param va `StateVariable` or `ActionVariable` or `StateBlock` or array variables and blocks (nested arrays of these things okay but not nested StateBlocks)
@comment User should typically not call this directly

@see StateVariable, DP::Actions, DP::EndogenousStates, DP::ExogenousStates, DP::SemiExogenousStates,DP::GroupVariables

**/
DP::AddStates(SubV,va) 	{
	decl pos, i, j;
	if (Flags::ThetaCreated) oxrunerror("DDP Error 36a. Error: can't add variable after calling DP::CreateSpaces()");
	if (!isarray(SubVectors)) oxrunerror("DDP Error 36b: can't add states before calling Initialize()");
	if (isclass(va,"Discrete")) va = {va};
	for(i=0;i<sizeof(va);++i)	{
        if (isarray(va[i])) {
            AddStates(SubV,va[i]);
            continue;
            }
		if (StateVariable::IsBlock(va[i])) {
			for (j=0;j<va[i].N;++j) {
				if (StateVariable::IsBlock(va[i].Theta[j])) oxrunerror("DDP Error 37. nested state blocks not allowed");
				AddStates(SubV,va[i].Theta[j]);
				va[i].Theta[j].block = va[i];
				va[i].Theta[j] = 0;		    //avoids ping-pong reference
				}
			va[i].pos = sizeof(Blocks);
			Blocks |= va[i];
			continue;
			}
		if (va[i].N<1) oxrunerror("DDP Error 38a. Cannot add variable with non-positive N");
        if (va[i].subv!=UnInitialized) oxrunerror("DDP Error 38b. Discrete Variable has already been added a vector.");
		switch_single(SubV) {
			case clock : TypeCheck(va[i],"TimeVariable","DDP Error 38c.Clock subvector must contain TimeVariables");
			case rgroup: if (va[i].N>1) {
							if (Flags::HasFixedEffect) oxrunerror("DDP Error 38d. random effect cannot be added AFTER any fixed effects have been added to the model");
							TypeCheck(va[i],"RandomEffect","DDP Error 38e. Only add RandomEffects to random effects vector");
							}
			case fgroup :  TypeCheck(va[i],"FixedEffect","DDP Error 38f. Only add FixedEffects to fixed effects vector");
						Flags::HasFixedEffect = TRUE;
			case acts : TypeCheck(va[i],"ActionVariable","DDP Error 38g. Only add ActionVariables to the action vector ");
			default   : TypeCheck(va[i],"StateVariable","DDP Error 38h. Only add StateVariable to state vectors");
			}
		pos = S[SubV].D++;
		SubVectors[SubV] |= va[i];
		S[SubV].N |= va[i].N;
		S[SubV].size *= va[i].N;
        va[i].subv = SubV;
		if (pos) S[SubV].C ~= (S[SubV].C[pos-1])*S[SubV].N[pos]; else S[SubV].C = S[SubV].N[pos];
		}
	}

/** Add `StateVariable`s to the endogenous vector $\theta$.
@param ... `StateVariable`s to add to $\theta$
**/
DP::EndogenousStates(...
    #ifdef OX_PARALLEL
    vs
    #endif
    )	{	AddStates(endog,vs); }

/** Add `StateVariable`s to the exogenous vector $\epsilon$.
@param ... Exogenous `StateVariable`s to add $\epsilon$
**/
DP::ExogenousStates(...
    #ifdef OX_PARALLEL
    vs
    #endif
) 	{ AddStates(exog,vs); } 	

/** Add `StateVariable`s to the semiexogenous vector $\eta$.
@param ... Semi-exogenous `StateVariable`s to add to $\eta$
**/
DP::SemiExogenousStates(...
    #ifdef OX_PARALLEL
    vs
    #endif
) 	{ AddStates(semiexog,vs); } 	

/** Add `TimeInvariant`s to the group vector $\gamma$.
@param ... `TimeInvariant`s to add to $\gamma$
**/
DP::GroupVariables(...
    #ifdef OX_PARALLEL
    va
    #endif
)	{
	decl cv,ccv;
    foreach(cv in va) {
    	if (isarray(cv)){
            foreach (ccv in cv) GroupVariables(ccv);
            }
        else {
		  if (isclass(cv,"FixedEffect")||isclass(cv,"FixedEffectBlock")) AddStates(fgroup,cv);
		  else if (isclass(cv,"RandomEffect")||isclass(cv,"RandomEffectBlock")) AddStates(rgroup,cv);
		  else oxrunerror("DDP Error 39. argument is not a TimeInvariant variable");
		  }
        }
	}

/** Add variables to the action vector $\alpha$.
@param ... `ActionVariable`s to add to $\alpha$

See <a href="Variables.ox.html#ActionVariables">Action Variables</a> for more explanation.

@example
<pre>
struct MyModel : Bellman {
    &vellip;
    static decl work;
    &vellip;
    }
&vellip;
Actions(work = new ActionVariable("w",2));
</pre>
</dd>

@comments
If no action variables are added to <code>MyModel</code> then a no-choice action is added by `DP::CreateSpaces`().
**/
DP::Actions(...
    #ifdef OX_PARALLEL
    va
    #endif
) 	{
	decl a, i, j, nr, pos=S[acts].D, sL;
    for(i=0;i<sizeof(va);++i)	{
        if (isarray(va[i])) {
            for(j=0;j<sizeof(va[i]);++j)
                Actions(va[i][j]);
            continue;
            }
        a = va[i];
        AddStates(acts,a);
		a.pos = pos;
		N::AA |= a.N;
		sL = a.L;
		if (!pos) {
			Alpha::Matrix = a.vals';
			Labels::V[avar] = {sL};
            Labels::Vprt[avar] = {abbrev(sL)};
			}
		else {
			Labels::V[avar] |= sL;
            Labels::Vprt[avar] |= abbrev(sL);
			nr = rows(Alpha::Matrix);
	 		Alpha::Matrix |= reshape(Alpha::Matrix,(a.N-1)*nr,pos);
			Alpha::Matrix ~= vecr(a.vals' * ones(1,nr));	 		
	 		}
        //if (DP::Volume>LOUD) println("Adding Action Variable to Action Vector","%c",Labels::V[avar],Alpha::Matrix);
		++pos;
		}
	}

/** Add `AuxiliaryValue`s to $\chi$.
@param ... `AuxiliaryValue`s <br\>
            or static function(s) that take no arugment, which will be sent to StaticAux<br/>
            or arrays of auxiliary variables and static functions to add to $\chi$

@see DP::Chi, StaticAux
**/
DP::AuxiliaryOutcomes(...
    #ifdef OX_PARALLEL
    va
    #endif
) {
	if (!isarray(SubVectors)) oxrunerror("DDP Error 40. Error: can't add auxiliary before calling Initialize()",0);
	decl pos = sizeof(Chi), i,j,s;
    foreach(s in va) {
        if (isarray(s))
            { foreach (j in s) AuxiliaryOutcomes(j); }
        else if (isfunction(s))
             AuxiliaryOutcomes(new StaticAux(sprint(s),s));
        else {
	       TypeCheck(s,"AuxiliaryValue");
	       Chi |= s;
	       if (!pos) {
                Labels::V[auxvar] = {s.L};
                Labels::Vprt[auxvar] = {abbrev(s.L)};
                }
           else {
                Labels::V[auxvar] |= s.L;
                Labels::Vprt[auxvar] |= abbrev(s.L);
                }
		   s.pos = pos++;
           N::aux = sizeof(Chi);
		  }
        }
	}

/** Create and return a list of auxiliary values for interactions.
@param ivar state variable or action variable to interact
@param olist Unitialized, no interaction</br>
       list of objects to interact with indicators for ivar
@param UseLabel:  use abbreviated ivar.L</br>
        string: start of column labels for matching to data.
@param ilo minimum value of ivar to track interaction (default=0)
@param ihi maximum index to track (default = 100)

For objects in data, tracked moment label must have the form
prefix_kk_xlabbrev

kk: current (not actual) value of ivar with a leading 0
xlabbrev: abbreviated label of member of olist (max 4 characters)

**/
DP::Interactions(ivar,olist,prefix,ilo,ihi) {
    decl n,k, ilist = {};
    olist = isarray(olist) ? olist : {olist};
    foreach(k in olist)
        for(n=max(0,ilo);n<min(ivar.N,ihi+1);++n) {
            ilist |= new Indicator(ivar,n,k,prefix);
            }
    return ilist;
    }

/** Create and return a list of auxiliary values for interactions.
@param ivar state variable or action variable to interact
@param olist Unitialized, no interaction</br>
       list of objects to interact with indicators for ivar
@param UseLabel:  use abbreviated ivar.L</br>
        string: start of column labels for matching to data.
@param ilo minimum value of ivar to track interaction (default=0)
@param ihi maximum index to track (default = 100)

For objects in data, tracked moment label must have the form
prefix_kk_xlabbrev

kk: current (not actual) value of ivar with a leading 0
xlabbrev: abbreviated label of member of olist (max 4 characters)

**/
DP::MultiInteractions(ivarlist,ilov,ihiv,olist,prefix) {
    decl k, ilist = {},nvec,d,M=sizeof(ivarlist);
    if (M!=rows(ilov)||M!=rows(ihiv)) oxrunerror("Arrays and bounds not same length");
    foreach(k in ivarlist[d]) { ihiv[d] = min(ihiv[d],k.N-1); }
    olist = isarray(olist) ? olist : {olist};
    nvec = ilov;
	d=1;				   							// start at leftmost state variable to loop over
	do	{
		do {
            foreach(k in olist) ilist |= new MultiIndicator(ivarlist,nvec,k,prefix);
			} while (++nvec[0]<=ihiv[0]);
		nvec[0] = ihiv[0];
		d = double(vecrindex(ihiv-nvec|1));
		if (d<M)	{
			++nvec[d];			   			//still looping inside
		    nvec[:d-1] = ilov[:d-1];		// (re-)initialize variables to left of d
			}
		} while (d<M);
    return ilist;
    }


/** Create auxiliary values that are indicators for a state or action.
@param ivar state variable or action variable to interact
@param UseLabel:  use abbreviated ivar.L</br>
        string: start of column labels for matching to data.
@param ilo minimum value of ivar to track interaction (default=0)
@param ihi maximum index to track (default = 100)

For objects in data, tracked moment label must have the form
prefix_kk


**/
DP::Indicators(ivar,prefix,ilo,ihi) {
    return Interactions(ivar,UnInitialized,prefix,ilo,ihi);
    }

/**Create an K+1-array of a state variable and K lags of its values.
@param L label
@param Target `StateVariable` to track
@param K positive integer, number of lags to track
@param Prune TRUE [default] if clock is finite horizon, presume all lags initialize to 0 and prune unreachable values.
@return K+1 - array, where the first element is the Target and the rest of the lagged values

@example
Create a binary Markov process and 3 lags, add all of them to &theta;
<pre>
status = KLaggedState(new Markov("q",<0.9,0.2;0.1,0.8>),3));
EndogenousStates(status);
</pre></dd>
**/
DP::KLaggedState(Target,K,Prune) {
    decl lv = new array[K+1],i;
    lv[0] = Target;
    for (i=1;i<K;++i) lv[i] = new LaggedState(Target.L+"_"+sprint(i),lv[i-1],Prune,i-1);
    return lv;
    }

/**Create an array of counters for different values of a state or action variable.
@param L label
@param Target `StateVariable` or `ActionVariable` to track with N-1 values
@param MaxCounts  N-vector where<br/>
            0 means do not track that value.  In this case, the corresponding state is `Fixed`<br/>
            M&gt;0, max count to keep.
@param Prune TRUE [default] if clock is finite horizon, then all but the last will be set as not PRUNED;  the
        first counted value will be a special state counter that stores the array and checks reachability for all of them.
@return array of state variables, Fixed and StateCounter.
@example
If m is state with 4 values, this will track values 1,2, and 3 up to limits of 8,20,20.
<pre>
mcount = new StateValuesCounters("M",&lt;0,8,20,20&gt;,TRUE));
EndogenousStates(status);
</pre></dd>
**/
DP::ValuesCounters(L,Target,MaxCounts,Prune) {
    decl lv = new array[Target.N],i,xcount=UnInitialized,sc = isclass(Target,"StateVariable");
    if (!isstring(L)) L="Count_"+Target.L;
    for (i=0;i<Target.N;++i) {
        if (!MaxCounts[i])
            lv[i] = new Fixed(L+sprint(i));
        else if (Prune && xcount==UnInitialized ) {
                xcount = i;
                if (sc)
                     lv[xcount] =new StateCounterMaster(L+"_"+sprint(xcount),int(MaxCounts[xcount]),Target,matrix(xcount));
                else lv[xcount] = new ActionCounterMaster(L+"_"+sprint(xcount),int(MaxCounts[xcount]),Target,matrix(xcount));
                }
        else {
            if (sc)
                lv[i]= new StateCounter(L+"_"+sprint(i),int(MaxCounts[i]),Target,matrix(i),FALSE,FALSE);
             else
                lv[i]= new ActionCounter(L+"_"+sprint(i),int(MaxCounts[i]),Target,matrix(i),FALSE,FALSE);
            }
        }
    lv[xcount].CVSList=lv;
    return lv;
    }

/**Create a K-array of lagged values of an action variable.
@param L label
@param Target `ActionVariable` to track
@param K positive integer, number of lags to track
@param Prune TRUE [default] if clock is finite horizon, presume all lags initialize to 0 and prune unreachable values.

@return K-array, of the lagged values of Target

@example
Create a binary choice.  Add 3 lags of it to &theta;
<pre>
d = new BinaryChoice("d");
status = KLaggedState(d,3);
EndogenousStates(status);
</pre></dd>


**/
DP::KLaggedAction(Target,K,Prune){
    decl lv = new array[K], i;
    lv[0] = new LaggedAction(Target.L+"."+sprint(0),Target,Prune,0);
    for (i=1;i<K;++i) lv[i] = new LaggedState(Target.L+"."+sprint(i),lv[i-1],Prune,i-1);
    return lv;
    }
	

/** The default Run() ... prints out a message.
@internal
**/
Task::Run() { println("Task::Run() ... should be replaced by a virtual Run()");    }


/** Base class for tasks involving random and fixed groups.
@internal
**/
GroupTask::GroupTask(caller) {
	Task(caller);
	span = bothgroup;	left = SS[span].left;	right = SS[span].right;
	}
	
GroupTask::~GroupTask() {
    delete qtask;
    ~Task();
    }

FETask::~FETask() {
    ~GroupTask();
    }

/** Loop over group-variable tasks.
@internal
**/
GroupTask::loop(IsCreator){
	Reset();
    #ifdef DEBUG
    if (trace) println("--Group task loop: ",classname(this),state[left:right]');
    #endif
	SyncStates(left,right);
	d=left+1;				   							// start at leftmost state variable to loop over
	do	{
		do {
			SyncStates(left,left);
            I::Set(state,Flags::ThetaCreated); //March 2019 removed TRUE to handle Ox8 new arrays
            #ifdef DEBUG
                if (trace) println("------Group task loop: ",isclass(I::curg)," ",I::r," ",I::f," ",classname(this)," Running ",state[left:right]');
            #endif
			if (IsCreator || isclass(I::curg) ) this->Run();
			} while (--state[left]>=0);
		state[left] = 0;
		d = left+double(vecrindex(state[left:right]|1));
        #ifdef DEBUG
            if (trace) println("----Group task loop: ",classname(this)," left:d:right",left,":",d,":",right,state[left:right]');
        #endif
		if (d<=right)	{
			--state[d];			   			//still looping inside
		    state[left:d-1] = N::All[left:d-1]-1;		// (re-)initialize variables to left of d
		    SyncStates(left,d);
			}
		} while (d<=right);
        #ifdef DEBUG
            if (trace) println("--Group Task Ending: ",classname(this));
        #endif
    return TRUE;
    }

/** Class to create $\Gamma$ space.
@internal
**/
CGTask::CGTask() {
	GroupTask();
	Gamma = new array[N::G];
	Fgamma = new array[N::F][N::R];
	gdist = zeros(N::F,N::R);
	loop(TRUE);
    }

/** .
@internal
**/
CGTask::Run() {
	Gamma[I::all[bothgroup]] =  (Flags::AllGroupsExist||any(Hooks::Do(GroupCreate)))
						? new Group(I::all[bothgroup],state)
						: 0;
    Fgamma[I::all[onlyfixed]][I::all[onlyrand]] = Gamma[I::all[bothgroup]];
	}
		
/** .
@internal
**/
DPMixture::DPMixture() 	{	RETask();	}

/** .
@internal
**/
DPMixture::Run() 	{	GroupTask::qtask->GLike();	}

/** The exogenous utility object.
@internal

Loop over the exogenous state space when $U(\alpha;...)$ needs to be computed.

**/
ExogUtil::ExogUtil() {
	ExTask();	
    subspace = iterating;
    AnyExog = SS[bothexog].size > One;
    U = UnInitialized;
	}

/** Compute $U$, either over all $\epsilon$ or just the current one.
@internal

@param howmany DOALL, loop or just current.

**/	
ExogUtil::ReCompute(howmany) {
    if ( SameDims(U,I::curth->GetPandV()) )
        U[][] = .NaN;
    else  U = constant(.NaN,I::curth->GetPandV());
    if (AnyExog && howmany==DoAll)
        this->ExTask::loop();
    else {
        state[left:right] = 0;
        SyncStates(left,right);
        I::SetExogOnly(state);
        Run();
        }
    }

ExogUtil::Run() {
    U[][I::all[bothexog]] = I::curth->Utility();
    }

/** Loop over $\eta$ space.
@internal
**/
SemiExTask::SemiExTask() {
	ExTask();	
    left = S[semiexog].M;  // right set in ExTask();
    subspace = iterating;
    AnyEta = SS[onlysemiexog].size > One;
    }

/** . @internal **/
SemiEV::SemiEV()       {     SemiExTask();    }

/** . @internal **/
SemiTrans::SemiTrans() {     SemiExTask();    }

/**  Redo computation over $\eta$ or current value (and over $\epsilon$).
@internal

This updates <code>pandv</code> which will already contain $U(\alpha;\cdots)$.

It calls the virtual `Bellman::ExogExpectedV`(). So it modifies the matrix as
    $$v(\alpha;\theta) += \delta E[V^\prime].$$


**/
SemiExTask::Compute(HowMany) {
    CurrExogWidth = I::curth->UseEps() ? N::Ewidth : One;
    if (AnyEta && HowMany==DoAll) {
        I::elo = 0;
        I::ehi = I::elo-1;
        this->ExTask::loop();
        }
    else {
        I::elo = I::all[onlysemiexog]*CurrExogWidth;
        I::ehi = I::elo-1;
        this->Run();
        }
    }

/** . @internal **/
SemiEV::Run() {
    I::ehi += CurrExogWidth;
    I::curth->ExogExpectedV();
	I::elo += CurrExogWidth;
    }

/** . @internal **/
SemiTrans::Run() {
    I::ehi += CurrExogWidth;
    I::curth->ExogStatetoState();
	I::elo += CurrExogWidth;
    }

/** . @internal **/
ExogOutcomes::ExogOutcomes() {    ExTask();   auxlist={}; }

/** Compute the expected values of tracked auxiliary variables over the exogenous vector &epsilon; **/
ExogOutcomes::ExpectedOutcomes(howmany,chq) {
    decl tv;
    this.chq = chq;
    foreach(tv in auxlist) { tv.track.v = 0.0; }
    I::curth->ThetaUtility();
    if (howmany==DoAll)
        loop();
    else {
        state[left:right] = 0;
        SyncStates(left,right);
        I::SetExogOnly(state);
        Run();
        }
    }

/** . @internal **/
ExogOutcomes::Run() {
    Hooks::Do(PreAuxOutcomes);
    I::curth->OutcomesGivenEpsilon(); //ExpectedOutcomesOverEpsilon(chq);
    if (Flags::Phase==PREDICTING) { // no need to do this when solving
        decl tv;
        foreach(tv in auxlist) {
            tv->Realize();
            tv.track.v += sumc(chq[][I::all[bothexog]].*tv.v);
            }
        }
    }

/** . @internal **/
ExogOutcomes::SetAuxList(tlist) {
    if (sizeof(auxlist)) return;  // already done
    decl tv;
    foreach (tv in tlist) if (isclass(tv,"AuxiliaryValue")) auxlist |= tv;
    }

/** Initialize $A(\theta)$ spaces.
@internal
**/
Alpha::Initialize() {
	Count = VZero;
	CList = array(Matrix);
	AList = array(Matrix);
	Sets = array(ones(N::A,1));
    AIlist = array(range(0,N::A-1)');
    N::Options = matrix(rows(Matrix));
    N::J = 1;
    N = A = C = UnInitialized;
    }

/** Set $A(\theta)$.
@internal
@param inAi NoMatch: set to 0, the master feasible set<br/>
            otherwise, set to $A(\theta)$ for current $\theta$.<br/>
            and, if also non-negative, then set the realized action values equal to the row inAi

**/
Alpha::SetA(inAi) {
    decl myj = (inAi==NoMatch) ? Zero : I::curth.Aind;
    C = CList[myj];
    A = AList[myj];
    N = rows(C);
    if (inAi<Zero)
        aI = aA = aC = UnInitialized;
    else {
        aI = inAi;
        aC = C[aI][];
        aA = A[aI][];
        }
    }

/** . @internal **/
Alpha::ClearA() { N = A = C = UnInitialized; }

/** Check $A(\theta)$ returned by `Bellman::FeasibleAction`(), add to list if new.
@internal
@param column vector of 0s and 1s indicating which $\alpha$ vectors are feasible at $\theta$

**/
Alpha::AddA(fa) {
    if (!ismatrix(fa)||rows(fa)!=rows(Sets[0])||columns(fa)>1 || ( sumc(fa.==1)+sumc(fa.==0) != rows(fa))  ) {
        println("DDP Error ??.  Improper FeasibleAction() return.\n"
                "Your method should return a ",N::Options[0]," x 1 vector of 0s and 1s.|n",
                "Instead it returned: ","%cf","%2.0f",fa);
        return Impossible;
        }
    decl nfeas = int(sumc(fa)), ai=0;
    do { if (fa==Sets[ai]) {++Count[ai]; break;} } while (++ai<N::J);
    if (ai==N::J) {
  	     Sets       |= fa;
         N::Options |= nfeas;
	     CList      |= selectifr(Matrix,fa);
	     AList      |= CList[N::J];
         AIlist     |= selectifr(AIlist[0],fa);
        ++N::J;
	    Count |= 1;
        }
   return ai;
   }

/** Reset the actual value matrices (based on possible changes in updated parameters).
@internal
@param alist list of action variables (`DP::SubVectors`[acts]).  Has to be passed because Alpha is defined before DP
@param CallUpdate TRUE [default]: call each actions `ActionVariable::Update`().<br/>
                   FALSE: don't call - this is for when feasible action sets are created and depend on static actual values.

 **/
Alpha::ResetA(alist,CallUpdate) {
    decl a, i, j=Zero;
    foreach (a in alist[i]) {
		if (CallUpdate) a->Update();
		if (!i) AList[j] = a.actual;
		else {
			decl nr = rows(AList[j]);
	 		AList[j] |= reshape(AList[j],(a.N-1)*nr,i);
			AList[j] ~= vecr(a.actual * ones(1,nr));
			}		
        }
    for (j=One;j<N::J;++j) AList[j][][] = selectifr(AList[Zero],Sets[j]);
    }

/** . @internal **/
Alpha::Aprint() {
    decl a,av,i,j;
    decl everfeasible, totalnever = 0;
    println("\n6. FEASIBLE ACTION SETS\n ");
    Rlabels = new array[N::J];
    aL1= "i    [";
	for (i=0;i<N::Av;++i) aL1 |= DP::SubVectors[acts][i].L[0];
    aL1 |= "]";
	av = sprint("%-14s",aL1);
	for (j=0;j<N::J;++j) av ~= sprint("  A[","%1u",j,"]   ");
	println("     ",av);
    print("     ","------------------"); for (j=0;j<N::J;++j) print("---------"); println("");
	for (a=0;a<N::A;++a) {
		for (i=0,av="     "+sprint("%03u",a)~" (";i<N::Av;++i) av ~= sprint("%1u",Matrix[a][i]);
		av~=")";
		for (j=0;j<N::J;++j)
            if (Sets[j][a]) {
                if (!sizeof(Rlabels[j])) Rlabels[j] = {av};
                else Rlabels[j] |= av;
                }
		for (i=0;i<8-N::Av;++i) av ~= " ";
        everfeasible = FALSE;
		for (j=0;j<N::J;++j) {
            av ~= Sets[j][a] ? "    X    " : "    -    ";
            everfeasible = everfeasible|| (Count[j]&&Sets[j][a]);
            }
        av ~= "    ";
		for (i=0;i<N::Av;++i)
            if ( isarray(DP::SubVectors[acts][i].vL) ) av ~= "-"~DP::SubVectors[acts][i].vL[Matrix[a][i]];
		if (everfeasible) println(av);  else ++totalnever;
		}
	for (j=0,av="   #States";j<N::J;++j) av ~= sprint("%9u",Count[j]);
	println("     ",av);
    print("     ","-----------------"); for (j=0;j<N::J;++j) print("---------");
    println("\n         Key: X = row vector is feasible. - = infeasible");
    if (totalnever) println("         # of Action vectors not shown because they are never feasible: ",totalnever);
    println("\n");
    }

/** .
@internal
**/
Labels::Initialize() {
    V = new array[NColumnTypes];
    Vprt = new array[NColumnTypes];
    decl vl;
    foreach(vl in V) vl = {};
    foreach(vl in Vprt) vl = {};
	format(1024);
    }

/** Reset all Flags.
@internal
**/
Flags::Reset() { delete UpdateTime; delete runtime; Phase = UpdateTime = StorePA = IsErgodic = NKstep = HasFixedEffect = ThetaCreated = FALSE; }

/** Reset all Sizes.
@internal
**/
N::Reset() {
    delete ReachableIndices, delete tfirst, delete insamp, delete SampleProportion ;
    SampleProportion = insamp = ReachableIndices =tfirst=T=G=F=R=S=A=Av=J=aux=TerminalStates=ReachableStates=Approximated = 0;
    }

/** Initializes size of spaces (only called internally).
 @internal

**/
N::Initialize() {
    G = DP::SS[bothgroup].size;
	R = DP::SS[onlyrand].size;
    DynR = DP::SS[onlydynrand].size;
	F = DP::SS[onlyfixed].size;
    Ewidth= DP::SS[onlyexog].size;
	A = rows(Alpha::Matrix);
	Av = sizec(Alpha::Matrix);
    /*	if (Flags::UseStateList) */
    tfirst = constant(UnInitialized,T,1);
    insamp = UnInitialized;
	ReachableStates = TerminalStates = 0;
    ReachableIndices = constant(.NaN,DP::SS[tracking].size,1);
    if (MaxSZ==Zero) MaxSZ = INT_MAX;
    }

/** Set up subsampling of the reachable state space based on a sampling strategy.
Sampling is only
@internal
**/
N::SetSubSample(InSampProp,MinSZ,MaxSZ) {
	SampleProportion = isdouble(InSampProp) ? constant(InSampProp,T,1) : InSampProp;
    this.MinSZ = MinSZ;
    this.MaxSZ = MaxSZ;
	Approximated = 0;
    if  ( isint(SampleProportion)||( (SampleProportion==1.0)&&(MaxSZ==INT_MAX) ) ) {
        if (isarray(insamp)) delete insamp;
        insamp = DoAll;
        return;
        }
    if (Flags::ThetaCreated) {
        if (DP::Volume>SILENT) println("New random subsampling of the state space");
        if (isint(insamp)) insamp = new array[T];
        SubSample();
        decl tt= new ReSubSample();
        if (DP::Volume>SILENT) println("Approximated: ",Approximated);
        delete tt;
        }
    }

N::SubSample() {
    decl t,c,nt=diff0(tfirst)[1:],d;
    for (t=0;t<T;++t) {
        c = min(MaxSZ,max(MinSZ,SampleProportion[t]*nt[t]));
        insamp[t] = (c<=nt[t]-1)
            ? ReachableIndices[tfirst[t]+ransubsample(c,nt[t])]
            : DoAll;
        }
    }

N::SubSampleDone() {
    if (!isarray(insamp)) return;
    decl t;
    for (t=0;t<T;++t) if (ismatrix(insamp[t])) insamp[t] = sizerc(insamp[t]);
    }

N::picked() {
    return isarray(insamp) ? (
                isint(insamp[I::t]) ? TRUE
                                    : any(insamp[I::t].==I::all[tracking])
                ) : TRUE;
    }

/** Compute size of spaces (only called internally).
@internal
**/
N::Sizes() {
	ReachableIndices = reversec(deleter(ReachableIndices));
    tfirst = 0 | (sizer(ReachableIndices)-tfirst);
    Mitstates = DP::SS[iterating].size;
    VV = new array[DVspace];
    for (decl i=0; i< DVspace;++i)
        VV[i] = zeros(1,N::Mitstates);
    }

/** . @internal **/
N::ZeroVV() {    VV[I::now][] = VV[I::later][] = 0.0; }

/** .
@internal
**/
N::print(){
	println("\n5. TRIMMING AND SUBSAMPLING OF THE ENDOGENOUS STATE SPACE (Theta)","%c",{"N"},"%r",{"    TotalReachable","         Terminal","     Approximated"},
    "%cf",{"%10.0f"},ReachableStates|TerminalStates|Approximated);
    if (T<=50)
        println("Index of first state by t (t=0..T-1)","%7.0f",tfirst');
    else
        println("Index of first state by t t=0..9 ","%7.0f",tfirst[0:9]',"and ",T-10,"...",T-1,"%7.0f",tfirst[T-10:]');
    }

/** Add trackind to the list of reachable indices (called internally).
@internal
@see FindReachables

**/
N::Reached(trackind) {
    ReachableIndices[ReachableStates++] = trackind;
    if (tfirst[I::t]<0) tfirst[I::t] = ReachableStates;
    }

/** . @internal **/
N::IsReachable(trackind) {
    return any(ReachableIndices.==trackind);
    }

/** Initialize static members.
@param userState a `Bellman`-derived object that represents one point
    $\theta$ in the user's endogenous state space $\Theta$. The Ox
    <code>clone()</code> function is used to copy this object to fill out $\Theta$.
    This also allows <code>userReachable()</code> to be a virtual function
@param UseStateList TRUE, traverse the state space $\Theta$ from a list of reachable indices<br>
					FALSE (default), traverse $\Theta$ through iteration on all state variables

@comments
Each DDP has its own version of Initialize, which will call this as well as do further set up.

<code>MyModel</code> MUST call <code>DPparent::Initialize</code> before adding any variables to the model.

UseStateList=TRUE may be much faster if the untrimmed state space is very large compared to the trimmed (reachable) state space.

**/
DP::Initialize(userState,UseStateList) {
    decl subv;
    Version::Check();
    TypeCheck(userState,"DP","DDP Error 05.  You must send an object of your Bellman-derived class to Initialize.  For example,\n Initialize(new MyModel()); \n");
    if (Flags::ThetaCreated) oxrunerror("DDP Error 42. Must call DP::Delete between calls to CreateSpaces and Initialize");
    if (isint(L)) L = "DDP";
    lognm = replace(Version::logdir+"DP-"+L," ","")+".log";
    logf = fopen(lognm,"av");
    fprintln(logf,"**** ",Version::tmstmp," ****");
    //Discrete::logf = fopen(replace(Version::logdir+"Variables-"+L+Version::tmstmp+".log"," ",""),"aV");
    Hooks::Reset();
    this.userState = userState;
    Flags::UseStateList=UseStateList;
	Flags::AllGroupsExist = TRUE;
    I::NowSet();
 	SubVectors = new array[DSubVectors];
    Alpha::Matrix = N::AA = N::Options = <>;
    Blocks = Gamma = Theta =  States = Labels::Sfmts= Chi = {};
    Labels::Initialize();
	SS = new array[DSubSpaces];
 	S = new array[DSubVectors];
 	for (subv=0;subv<DSubVectors;++subv)  	{ SubVectors[subv]={}; S[subv] = new Space(); }
 	for (subv=0;subv<DSubSpaces;++subv)   	{ SS[subv]= new SubSpace();  }
	F = new array[DVspace];
	P = new array[DVspace];
	//alpha =
    //  chi =
    // zeta =
    delta = Impossible;
    SetUpdateTime();
    if (strfind(arglist(),"NOISY")!=NoMatch) {
            Volume = NOISY;
            if (!Version::MPIserver) println(Volume,arglist());
            }
    if (Volume>SILENT && !Version::MPIserver)
        println("DP::Intialize is complete. Action and State spaces are empty.\n Log file name is: ",lognm);
 }

/** Tell DDP when parameters and transitions have to be updated.
@param time `UpdateTimes` [default=AfterRandom]

THe default allows for transitions that depend on dynamically determined parameters,
<em>and</em> the current value of `FixedEffect` variables (if there are any), and `RandomEffect` variables (if there are any).

@example

MyModel is simpler than the default:  it has no dynamically determined parameters, so transitions
can calculated once-and-for-all when spaces are created:
<pre>
&vellip;
SetUpdateTime(InCreateSpaces);  //have to tell me before you call CreateSpaces!
CreateSpaces();
</pre>
MyModel is still simpler than the default, but its transitions do depend on dynamic parameters (say
an estimated parameter).  So transitions have to be updated each time all solutions are initiated
by `Method::Solve`() and can't just be done in <code>CreateSpaces</code>.
<pre>
&vellip;
CreateSpaces();
SetUpdateTime(OnlyOnce);   // can be set after CreateSpaces
</pre>
MyModel is still simpler than the default, but its transitions do depend on the values of FixedEffects. RandomEffects
do not affect transitions, only utility so transitions do not have to be updated with each change in random effects:
<pre>
&vellip;
CreateSpaces();
SetUpdateTime(AfterFixed);
</pre>

</DD>

**/
DP::SetUpdateTime(time) {
    if (isint(Flags::UpdateTime)) Flags::UpdateTime = constant(FALSE,UpdateTimes,1);
    if (!isint(time) ) oxrunerror("DDP Error 43a. Update time must be an integer");
    if (Flags::ThetaCreated) {
        if (time==AfterRandom) oxrunerror("Cannot set UpdateTime=AfterRandom after CreateSpaces has been called.");
        if (time==InCreateSpaces) oxrunerror("Cannot specify UpdateTime as InCreateSpaces after CreateSpaces has been called");
        }
    if (Volume>QUIET && !Version::MPIserver)
        switch_single (time) {
            case InCreateSpaces : oxwarning("DDP Warning 13a.\n Transitions and actual values are fixed.\n They are computed in CreateSpaces() and never again.\n");
            case WhenFlagIsSet  : oxwarning("DDP Warning 13aa.\n Setting update time only if RecomputeTrans() has been called.\n Transitions and actual values are the same for all calls to Solve() until RecomputeTrans() is called again.\n");
            case OnlyOnce       : oxwarning("DDP Warning 13b.\n Setting update time to OnlyOnce.\n Transitions and actual values do not depend on fixed or random effect values.\n  If they do, results are not reliable.\n");
            case AfterFixed     : oxwarning("DDP Warning 13c.\n Setting update time to AfterFixed.\n Transitions and actual values can depend on fixed effect values but not random effects.\n  If they do, results are not reliable.\n");
            case AfterRandom    : oxwarning("DDP Warning 13d.\n Setting update time to AfterRandom.\n Transitions and actual values can depend on fixed and random effects,\n  which is safe but may be redundant and therefore slower than necessary.\n");
            default             : oxrunerror("DDP Error 43b. Update time must be between 0 and UpdateTimes-1");
            }
    Flags::UpdateTime[] = FALSE;
    Flags::UpdateTime[time] = TRUE;
    if (time==WhenFlagIsSet) Flags::CallTrans = TRUE;
    }

/**  If changing fixed parameters and UpdateTime==WhenFlagIsSet then next Solve() will recompute transitions.
**/
DP::RecomputeTrans() {
    Flags::CallTrans = TRUE;
    }

/** Request that the State Space be subsampled for extrapolation methods such as `KeaneWolpin`.
@param SampleProportion 0 &lt; double &le; 1.0, fixed subsample size across <var>t</var><br>
N::T&times;1 vector, time-varying sampling proportions.<br>
[default] 1.0: do not subsample at all, visit each state.

@param MinSZ minimum number of states to sample each period [default=0]
@param MaxSZ maximum number of states to sample each period [default=INT_MAX, no maximum]

@example
Suppose that <code>N::T=4</code>
<pre>SubSampleStates(<1.0;0.9;0.75;0.5>);</pre>
This will sample half the states in the last period, 3/4 of the states in period 2, 90% in period 1
and all the states in period 0.
<pre>SubSampleStates(1.0,0,100);</pre>
This will ensure that more than 100 states are subsampled each period.  If there are fewer reachable states
than 100 at <code>t</code> then all states are sampled and the solution is exact.
<pre>SubSampleStates(0.8,30,200);</pre>
This will sample 80% of states at all periods, but it will guarantee that no fewer than 30 and no more than 200
are sampled in any one period.
</dd>

<DT>Notes</DT>
<DD>If called before <code>CreateSpaces()</code> the subsampling actually occurs during
`DP::CreateSpaces`().</DD>

<DD>If called after <code>CreateSpaces()</code> then the new sampling scheme occurs immediately.
Storage for U and &Rho;() is re-allocated accordingly.</DD>

**/
DP::SubSampleStates(SampleProportion,MinSZ,MaxSZ) {
	if (!sizerc(SubVectors[clock]))	{
		if (!Version::MPIserver)
            oxwarning("DDP Warning 14.\n Clock must be set before calling SubsampleStates.\n  Setting clock type to InfiniteHorizon.\n");
		SetClock(InfiniteHorizon);
		}
    N::SetSubSample(SampleProportion,MinSZ,MaxSZ);
    }

/** For debugging: Set a flag so that CreateSpaces does not actually create the space.
**/
DP::onlyDryRun() {
    if (Flags::ThetaCreated) {
        oxwarning("DDP Warning 15.\n State Space Already Defined.\n DryRun request ignored.\n");
        return;
        }
    oxwarning("DDP Warning 16.\n Only a dry run of creating the state space Theta will be performed.\n Program ends at the end of CreateSpaces().\n");
    Flags::onlyDryRun=TRUE;
    }

/** Initialize all spaces.
@comments No actions or variables can be added after CreateSpaces() has been called. </br>
**/
DP::CreateSpaces() {
   if (Flags::ThetaCreated) oxrunerror("DDP Error 44. State Space Already Defined. Call CreateSpaces() only once");
   Flags::NewPhase(INITIALIZING);
   decl subv,i,pos,m,bb,sL,j,av, sbins = zeros(1,NStateCategories),w0,w1,w2,w3, tt,lo,hi,inargs = arglist();
   if (strfind(inargs,"NOISY")!=NoMatch) Volume=NOISY;
    if (!S[acts].D) {
		if (!Version::MPIserver) oxwarning("DDP Warning 17.\n No actions have been added to the model.\n A no-choice action inserted.\n");
		Actions(new ActionVariable());
		}
	S[acts].M=0;
	S[acts].X=S[acts].D-1;
	for (subv=LeftSV,pos=0,N::All=<>,S[LeftSV].M=0; subv<DSubVectors;++subv)	{
		if (subv>LeftSV) S[subv].M = S[subv-1].X+1;
		if (!sizerc(SubVectors[subv]))	{
			if (subv==clock) {
				if (!Version::MPIserver) oxwarning("DDP Warning 18.\n Clock has not been set.\n Setting clock type to InfiniteHorizon.\n");
				SetClock(InfiniteHorizon);
				}
			else if (subv==rgroup) {AddStates(rgroup,new RandomEffect("r",1));}
			else if (subv==fgroup) {AddStates(fgroup,new FixedEffect("f",1));}
			else AddStates(subv, new Fixed("s"+sprint("%u1",subv)));
			}
		S[subv].X = S[subv].M+S[subv].D-1;
		for(m=0;m<sizeof(SubVectors[subv]);++m,++pos) {
			SubVectors[subv][m].pos = pos;
			States |= SubVectors[subv][m];
			sL = SubVectors[subv][m].L;
			if (( ismember(bb=SubVectors[subv][m],"block") ))  			
				bb.block.Theta[bb.bpos] = pos;
            if (!sizeof(Labels::V[svar])) {
                Labels::V[svar] = {sL};
                Labels::Vprt[svar] = {abbrev(sL)};
                }
            else {
			 Labels::V[svar] |= sL;
             Labels::Vprt[svar] |= abbrev(sL);
             }
			Labels::Sfmts |= Labels::sfmt;
			}
		N::All |= S[subv].N;
		}
	NxtExog = new array[TransOutput];
    N::S = rows(N::All);
	SubSpace::S = S;
	SubSpace::ClockIndex = clock;
	SS[onlyacts]	->ActDimensions();
	SS[onlyexog]	->Dimensions(<exog>);
	SS[onlysemiexog]->Dimensions(<semiexog>);
	SS[bothexog] 	->Dimensions(<exog;semiexog>);
	SS[onlyendog]	->Dimensions(<endog>);
	SS[tracking]	->Dimensions(<endog;clock>,FALSE);
	SS[onlyclock]	->Dimensions(<clock>,FALSE);
    SS[iterating]	->Dimensions(<endog;clock>);
	SS[onlyrand]	->Dimensions(<rgroup>,FALSE,TRUE);
    SS[onlydynrand] ->Dimensions(<rgroup>,FALSE,Flags::UpdateTime[AfterRandom]);
	SS[onlyfixed]	->Dimensions(<fgroup>,FALSE);
	SS[bothgroup]	->Dimensions(<rgroup;fgroup>,FALSE,TRUE);
	SS[allstates]	->Dimensions(<exog;semiexog;endog;clock;rgroup;fgroup>,FALSE,TRUE);
    N::Initialize();
    Alpha::Initialize();
	if (Flags::UseStateList) {
		if (isclass(counter,"Stationary")) oxrunerror("DDP Error 45. canNOT use state list in stationary environment");
		}
    Flags::IsErgodic = counter.IsErgodic;
	if (!Version::MPIserver && Volume>SILENT)	{		
        if (Version::HTopen) println("</pre><a name=\"Summary\"/><pre>");
		println("-------------------- DP Model Summary ------------------------\n");
		w0 = sprint("%",7*S[exog].D,"s");
		w1 = sprint("%",7*S[semiexog].D,"s");
		w2 = sprint("%",7*S[endog].D,"s");
		w3 = sprint("%",7*S[clock].D,"s");

        println("0. USER BELLMAN CLASS\n    ",classname(userState),parents);
        println("1. CLOCK\n    ",ClockType,". ",ClockTypeLabels[ClockType]);
		println("2. STATE VARIABLES\n","%18s","|eps",w0,"|eta",w1,"|theta",w2,"-clock",w3,"|gamma",
		"%r",{"       s.N"},"%cf","%7.0f","%c",Labels::Vprt[svar],N::All');
		for (m=0;m<sizeof(States);++m)
			if (!isclass(States[m],"Fixed")&&States[m].N>1)
			++sbins[  isclass(States[m],"NonRandom") ? NONRANDOMSV
					 :isclass(States[m],"Random") ? RANDOMSV
					 :isclass(States[m],"Augmented") ? AUGMENTEDV
                     :isclass(States[m],"TimeVariable")? TIMINGV
                     :isclass(States[m],"TimeInvariant") ? TIMEINVARIANTV
                     : COEVOLVINGSV ];
		println("\n     Transition Categories (not counting placeholders and variables with N=1)","%r",{"     #Vars"},"%c",{"NonRandom","Random","Coevolving","Augmented","Timing","Invariant"},"%cf",{"%13.0f","%13.0f","%13.0f","%13.0f","%13.0f"},sbins);

		println("\n3. SIZE OF SPACES\n","%c",{"Number of Points"},"%r",
				{"    Exogenous(Epsilon)",
                 "    SemiExogenous(Eta)",
                 "   Endogenous(Theta_t)",
                 "                 Times",
                 "         EV()Iterating",
				 "      ChoiceProb.track",
                 "         Random Groups",
                 " Dynamic Random Groups",
                 "          Fixed Groups",
                 "   Total Groups(Gamma)",
                 "       Total Untrimmed"},
							"%cf",{"%17.0f"},
			SS[onlyexog].size|SS[onlysemiexog].size|SS[onlyendog].size|SubVectors[clock][0].N|SS[iterating].size|SS[tracking].size|N::R|N::DynR|N::F|N::G|SS[allstates].size);
		print("\n4. ACTION VARIABLES\n   Number of Distinct action vectors: ",N::A);
		println("%r",{"    a.N"},"%cf","%7.0f","%c",Labels::Vprt[avar],N::AA');
		}
	Theta = new array[SS[tracking].size];
    I::Initialize();
    Alpha::ResetA(SubVectors[acts]);
    Alpha::SetA(NoMatch);
    I::curth = I::curg = UnInitialized;
    tt = new CreateTheta();
    tt->loop();
    N::Sizes();
    if (!Version::MPIserver && Volume>LOUD) {
            println("Note: Reachability of all states listed in the log file");
            if (isfile(logf)) fprintln(logf,"0=Unreachable because a state variable is inherently unreachable\n",
                              "1=Unreacheable because a user Reachable returns FALSE\n",
                              "2=Reachable",
                "%8.0f","%c",{"Reachble"}|{"Tracking"}|Labels::Vprt[svar][S[endog].M:S[clock].M],tt.rchable);
                }
    Alpha::ClearA();
    //delete tt.insamp;
	delete tt;
	if ( !Version::MPIserver && Flags::IsErgodic && N::TerminalStates )
        oxwarning("DDP Warning 19.\n clock is ergodic but terminal states exist?\n Inconsistency in the set up.\n");
	tt = new CGTask();	delete tt;
    Flags::ThetaCreated = TRUE; //March 2019 moved below group creation for Ox8 handling of new arrays
	//if (isint(zeta)) zeta = new ZetaRealization(0);
    if (!Version::MPIserver) {
        if (N::R>1 && !Flags::UpdateTime[AfterRandom])
            oxwarning("DDP Warning ??.\n Model contains random effects but Transition UpdateTime is not AfterRandom.\n If transitions depend on random effects they will be INCORRECT." );
        else if (N::F>1 && !Flags::UpdateTime[AfterFixed])
            oxwarning("DDP Warning ??.\n Model contains fixed effects but Transition UpdateTime is not AfterFixed.\n If transitions depend on fixed effects they will be INCORRECT." );
        }
	DPDebug::Initialize();
  	V = new matrix[1][SS[bothexog].size];
	if (!Version::MPIserver && Volume>SILENT)	{		
        N::print();
        Alpha::Aprint();
        if (N::aux) {
            println("\n7. AUXILIARY OUTCOMES\n      ");
            decl ax,ten=0 ;
            foreach(ax in Chi)
                print(ax.L,!imod(++ten,10) ? "\n" : "      ");  //," Columns=",ax.N
            println("\n\n");
            }
		}
    if (!Version::MPIserver && Flags::onlyDryRun) {println(" Dry run of creating state spaces complete. Exiting "); exit(0); }
	ETT = new EndogTrans();
    if (Flags::UpdateTime[InCreateSpaces]||Volume>LOUD) {
        ETT->Transitions();
        if (!Version::MPIserver && Volume>LOUD) {
            oxwarning("Checked for valid transitions.  Look in the log file for problems.");
            --Volume;
            }
        }
   XUT   = new ExogUtil();
   IOE   = new SemiEV();
   EStoS = new SemiTrans();
   EOoE  = new ExogOutcomes();
   if (!Version::MPIserver && Volume>SILENT) println("-------------------- End of Model Summary ------------------------\n");
   Flags::NewPhase(INBETWEEN,!Version::MPIserver && Volume>SILENT);
   Data::SetLog();
 }

/**Return choice probabilities conditioned on &theta; expanded into full choice probabilty space.
@internal

@param  Aind  index of feasible` set that p0 is based on
@param  p0  matrix of conditional choice probabilities to expand.

this inserts zeros for infeasible action vectors.  So results are consistent
across states that have different feasible action sets.

@return expanded matrix

@see DPDebug::outV

**/
DP::ExpandP(Aind,p0) {
	decl p,i;
    p = p0;
	for (i=0;i<N::A;++i)
        if (!Alpha::Sets[Aind][i]) p = insertr(p,i,1);
	return p;
	}

/** .
@internal
**/
Task::Task(caller)	{
	state 	= N::All-1;
	itask = subspace = UnInitialized;
    this.caller = caller;
	MaxTrips = INT_MAX;
    done = FALSE;
	}

Task::~Task()	{
    delete itask;
    delete state;
    }

/** .
@internal
**/
Task::Reset() {
	state[left:right] = N::All[left:right]-1;
	}

/** .
@internal
**/
ThetaTask::ThetaTask(subspace,mycaller) {
	Task(mycaller);
	left = S[endog].M;
	right = S[clock].M;
	this.subspace = subspace;
    }

/* .
@internal

CreateTheta::Sampling() {
    N::Subsample();
    //Flags::DoSubSample = constant(FALSE,N::T,1);
    if (isarray(N::insamp)) {  //some time periods have subsampling
        decl a, t;
        foreach(a in N::insamp[t])
            Flags::DoSubSample[t] = !isint(a);  //t has subsampling (otherwise all states visited)
        }
    }	
*/

/** Called in CreateSpaces to set up &Theta;.

**/
CreateTheta::CreateTheta() {
	ThetaTask(tracking);
    thx = DP::SubVectors[endog];
    N::SetSubSample();
	}

/** .
@internal
**/
CreateTheta::Run() {
    }

ReSubSample::ReSubSample() {
	ThetaTask(tracking);
    Task::loop();  //don't use CreateTheta::loop()
    N::SubSampleDone();
    }

/** . @internal **/
ReSubSample::Run() {  I::curth->Allocate(N::picked());     }

CreateTheta::loop() {
    decl v,vk,ign;
	trips = iter = 0;
	Reset();					// (re-)initialize variables in range
	SyncStates(0,N::S-1);
	d=left+1;				   		// start at leftmost state variable to loop over	
    Flags::SetPrunable(counter);
    do	{
        I::all[] = I::OO*state;
        Theta[I::all[tracking]]=Impossible;   //not .Null if unreachable
        rch = TRUE;
        foreach (v in thx[vk])      //April 2020.  All must be checked each time because of dependencies
            if (!v->IsReachable()) { rch=FALSE; break; }
	    if ( rch  && (userState->Reachable()) ) {
            N::Reached(I::all[tracking]);
            if (!Flags::onlyDryRun) {
                Theta[I::all[tracking]] = clone(userState,Zero);
		        Theta[I::all[tracking]] ->SetTheta(state,N::picked());
                }
            }
		++iter;
        inner = (--state[left]>=0);
        if (!inner) {
		  state[left] = 0;
		  d = left+double(vecrindex(state[left:right]|1));
		  if (d<right) --state[d]; //still looping inside
		  else {
            if ( this->Update() == IterationFailed ) return IterationFailed;
            Flags::SetPrunable(counter);
            }
		  state[left:d-1] = N::All[left:d-1]-1;		// (re-)initialize variables to left of d
		  SyncStates(left,d);
          }
        else {
        	SyncStates(left,left);
            }
		} while ( inner ||  (d<=right) );  //Loop over variables to left of decremented, unless all vars were 0.
    N::SubSampleDone();
    return TRUE;
    }

/** Loop through the state space and carry out tasks leftgrp to rightgrp.
@internal
**/
Task::loop(){
	trips = iter = 0;
	Reset();					// (re-)initialize variables in range
    #ifdef DEBUG
        if (trace) println("*** Task Loop ",classname(this),state');
    #endif
	SyncStates(0,N::S-1);
	d=left+1;				   		// start at leftmost state variable to loop over	
    done = FALSE;
    do	{
		SyncStates(left,left);
        if (I::Set(state)) this->Run();
		++iter;
        inner = (--state[left]>=0);
        if (!inner) {
		  state[left] = 0;
		  d = left+double(vecrindex(state[left:right]|1));
		  if (d<right) --state[d];			   			//still looping inside
		  else {
            if ( this->Update() == IterationFailed ) return IterationFailed;
            }
		  state[left:d-1] = N::All[left:d-1]-1;		// (re-)initialize variables to left of d
		  SyncStates(left,d);
          }
		} while ( inner ||  (d<=right) || !done );  //Loop over variables to left of decremented, unless all vars were 0.
    #ifdef DEBUG
        if (trace) println("*** End Loop ",classname(this));
    #endif
    return TRUE;
    }

/** Loop through Exogenous States (more efficient than general code).
@internal
**/
ExTask::loop(){
	trips = iter = 0;
	Reset();					// (re-)initialize variables in range
    #ifdef DEBUG
        if (trace) println("*** Task Loop ",classname(this),state');
    #endif
    SyncStates(left,right);  // is this wrong???
	d=left+1;				   		// start at leftmost state variable to loop over	
    done = FALSE;
	do	{
		SyncStates(left,left);
        I::SetExogOnly(state);
		this->Run();
		++iter;
        inner = (--state[left]>=0);
        if (!inner) {
		  state[left] = 0;
		  d = left+double(vecrindex(state[left:right]|1));
		  if (d<right) --state[d];			   			//still looping inside
		      else this->Update();
		  state[left:d-1] = N::All[left:d-1]-1;		// (re-)initialize variables to left of d
		  SyncStates(left,d);
          }
		} while (inner || (d<=right) || !done );  //Loop over variables to left of decremented, unless all vars were 0.
    #ifdef DEBUG
        if (trace) println("*** End Loop ",classname(this));
    #endif
    return TRUE;
    }


/** Default task loop update process.
@internal
@return TRUE if rightmost state &gt; 0<br/>
FALSE otherwise.

**/
Task::Update() {
	done = !state[right];
	++trips;
    if (!done) --state[right];	
	return done;
	}
	
/** Process a vector (list) of state indices.
@param DoAll go through all reachable states<br>
	   non-negative integer, initial t<br>
@param var0<br>
		non-negative integer, the time period to loop over<br>
		lohi matrix of first and last index to process

**/
Task::list(span,inlows,inups) {
	decl lft = left ? state[:left-1] : <>,
		 rht = right<N::S-1 ? state[right+1:] : <> ,
		 rold, ups, lows, s, news, indices;
    oxwarning(" Don't use list processing on Stationary/Ergodic clocks yet!!!");
    #ifdef DEBUG
        if (trace) println("*** Task List: ",classname(this),state');
    #endif
	trips = iter = 0;
	SyncStates(0,N::S-1);
	if (isint(span)) {
		indices = N::ReachableIndices;
		if (span==DoAll)  {	//every reachable state
			s=ups=N::ReachableStates-1; lows = 0;
			}
		else {
			s = ups=N::tfirst[span+1]-1;
			lows = N::tfirst[inlows==UseDefault ? span : inlows];
			}
		}
	else {		
		indices = span;
		s = ups = inups==UseDefault ? sizer(indices)-1 : inups;
        lows = inlows==UseDefault ? 0 : inlows;
		}
	done = FALSE;
	do {
	   rold = state[right];
	   news = lft | ReverseState(indices[s],tracking)[left:right] | rht;
	   if (s<ups && news[right]<rold) {
            if ( this->Update() == IterationFailed ) return IterationFailed;
            }
	   state = news;
	   SyncStates(left,right);
       if (I::Set(state)) this->Run();
	   ++iter;
	   } while (--s>=lows);
    #ifdef DEBUG
        if (trace) println("*** End List: ",classname(this));
    #endif
	if (!done) return this->Update();
    }
		
/** .
@internal
**/
Task::Traverse(span,lows,ups) {
	if (Flags::UseStateList) {
        oxrunerror("spanning the space as a list not supported in this version of niqlow.  Use the loop() option");
        return list(span,lows,ups);
        }
	else
 		return loop();
	}

	
/** Compute the distribution of Exogenous state variables, $P(\epsilon)$.
@internal
This is or should be called each time a value function iteration method begins.
Result is stored in the static `DP::NxtExog` array.

**/
DP::ExogenousTransition() {
    decl N,root,k,curst,si = SS[bothexog].D-1,
		prob, feas, bef=NOW, cur=LATER,
		Off = SS[bothexog].O;
	 F[bef] = VZero;	 	 P[bef] = <1.0>;
	 do {
	 	F[cur] = <>;   P[cur] = <>;
		curst = States[si];
		if (isclass(curst,"Coevolving"))
			{N =  curst.block.N; root = curst.block; }
		else
			{ N = 1; root = curst; }
		[feas,prob] = root -> Transit();
		feas = Off[curst.pos-N+1 : curst.pos]*feas;
		k=0;
		do if (prob[k])	{
			 F[cur]  ~=  F[bef]+feas[][k];
			 P[cur]  ~=  P[bef].*prob[][k];
			 } while (++k<columns(prob));
		cur = bef; 	bef = !cur;	si -= N;
		} while (si>=0);
	NxtExog[Qind] = F[bef][];
	NxtExog[Qprob] = P[bef][]';
    #ifdef DEBUG
        if (Volume>LOUD) { decl d = new DumpExogTrans(); delete d; }
    #endif
 }

/** Display the exogenous transition as a matrix.

**/
DumpExogTrans::DumpExogTrans() {
	ExTask();
	s = <>;
	loop();
	print("Exogenous and Semi-Exogenous State Variable Transitions ","%c",{" "}|Labels::Vprt[svar][S[exog].M:S[semiexog].X]|"f()","%cf",array(Labels::Sfmts[0])|Labels::Sfmts[3+S[exog].M:3+S[semiexog].X]|"%15.6f",s);
	delete s;
	}
	
/** . @internal **/
DumpExogTrans::Run() { decl i =I::all[bothexog];  s|=i~state[left:right]'~NxtExog[Qprob][i];}


/** Set the discount factor, $\delta$.
 @param delta, `CV` compatible object (`Parameter` or <code>double</code> or <code>function</code>)
**/
DP::SetDelta(delta) 	{ 	return CV(this.delta = delta);	 }	

/** Ensure that all `StateVariable` objects <code>v</code> are synched with the internally stored state vector.
@param dmin leftmost state variable
@param dmax rightmost state variable
@return the value of the dmax (rightmost)

@comments
If the clock is within the range of states to synch then `Clock::Synch`() is called at the end.
**/
Task::SyncStates(dmin,dmax)	{
	for (sd=dmin;sd<=dmax;++sd) {
		Sd = States[sd];
		sv = Sd.v = state[sd];
  		if (isclass(Sd,"Coevolving")) {
			Sd.block.v[Sd.bpos] = sv;
			if (sv>-1) Sd.block->myAV();  // Sd.block.actual[Sd.bpos] = Sd.actual[sv];	
			}
		}
    if (dmin<=S[clock].M && dmax>= S[clock].M) counter->Synch();
	return sv;
	}

/** Ensure that `ActionVariable` current values (<code>v</code>) is synched with the choice vector $\alpha$.
@param a action vector.
**/
DP::SyncAct(a)	{
	decl d;
	for (d=0;d<S[acts].D;++d) SubVectors[acts][d].v = a[d];
	}

/** Set the model clock.
@param ClockOrType `Clock` derived state block<br>
	   integer, `ClockTypes`
@param ... arguments to pass to constructor of clock type

@example
<pre>
Initialize(Reachable);
SetClock(InfiniteHorizon);
&vellip;
CreateSpaces();
</pre>
Finite Horizon
<pre>
decl T=65;	
Initialize(Reachable);
SetClock(NormalAging,T);
&vellip;
CreateSpaces();
</pre>
Early Mortaliy
<pre>
MyModel::Pi();	

SetClock(RandomMortality,T,MyModel::Pi);
Initialize(Reachable);
&vellip;
CreateSpaces();

</pre></dd>

@comments <code>MyModel</code> can also create a derived `Clock` and pass it to SetClock.
		
**/
DP::SetClock(ClockOrType,...
    #ifdef OX_PARALLEL
    va
    #endif
)	{
	if (isclass(counter)) oxrunerror("DDP Error 46. Clock/counter state block already initialized");
	if (isclass(ClockOrType,"Clock")) {
        counter = ClockOrType;
        ClockType = UserDefined;
        }
	else {
        ClockType = ClockOrType;
		switch(ClockType) {
			case Ergodic:				counter = new Stationary(TRUE); break;
			case InfiniteHorizon: 		counter = new Stationary(FALSE); break;
            case SubPeriods:            switch(sizeof(va)) {
                                          case 0 :
                                          case 1 : oxrunerror("DDP Error ???. SubPeriods (Divided) clock requires 2,3, or 4 arguments");
                                                    break;
                                          case 2 : counter = new Divided(va[0],va[1],va[2]); break;
                                          case 3 : counter = new Divided(va[0],va[1],va[2],va[3]); break;
                                          default: oxrunerror("DDP Error ???. SubPeriods (Divided) clock requires 2,3, or 4 arguments");
                                                    break;
                                          }
                                         break;
			case NormalAging:  			counter = new Aging(va[0]); break;
			case StaticProgram:			counter = new StaticP(); SetDelta(0.0); break;
			case RandomAging:			counter = new AgeBrackets(va[0]);  break;
			case RandomMortality:		counter = new Mortality(va[0],va[1]);  break;
            case UncertainLongevity:    counter = new Longevity(va[0],va[1]); break;
            case RegimeChange:          counter = new Regimes(va[0]); break;
			case SocialExperiment:		counter = new PhasedTreatment(va[0],TRUE);  break;
			default :                   oxrunerror("DDP Error ??. ClockType tag not valid");
			}
		}
	AddStates(clock,counter);
	N::T = counter.t.N;
	}

/** .
@internal
**/
SDTask::SDTask()  { RETask(); }

/** .
@internal
**/
SDTask::Run()   { I::curg->StationaryDistribution();}	


/** . @internal **/
ExTask::ExTask() {
	Task();	
    left = S[exog].M;	
    right = S[semiexog].X;	
    }
		
/** Create a new group node for value of $\gamma$ (called internally).
@internal
**/
Group::Group(pos,state) {
	this.state = state;
    this.state[Zero:SS[bothgroup].left-1] = 0;
	this.pos = pos;
	rind = I::all[onlyrand];
	find = I::all[onlyfixed];
	if (Flags::IsErgodic) {
		decl d = SS[onlyendog].size;
		Ptrans = new matrix[d][d];
		Pinfinity = new matrix[d];
		if (isint(PT)) {
			PT = new matrix[N::ReachableStates][N::ReachableStates];
			statbvector = 1|zeros(N::ReachableStates-1,1);
			}
		}
	else { Ptrans = Pinfinity = 0; }
	Palpha = (Flags::StorePA) ? new matrix[N::A][SS[tracking].size] : 0;
    mobj = UnInitialized;
	}

/** Delete a group.
@internal
**/
Group::~Group() {
  	if (!isint(Ptrans)) { delete Ptrans, delete Pinfinity; }
	Ptrans = Pinfinity = 0;
	if (!isint(Palpha)) delete Palpha;
	Palpha=0;
	if (!isint(PT)) { delete PT, delete statbvector; }
	PT = statbvector = 0;
	}
	
/** Copy elements of state vector into <code>.v</code> for group variables.
 @internal
**/
Group::Sync()	{
	decl d,sv,Sd;
	for (d=SS[bothgroup].left;d<=SS[bothgroup].right;++d) {
		Sd = States[d];
		sv = Sd.v = state[d];
		if (StateVariable::IsBlockMember(States[d])) {
			Sd.block.v[Sd.bpos] = sv;
			if (sv>-1) Sd.block.actual[Sd.bpos] = Sd.actual[sv];	
			}
		}
	return sv;
	}

/** Compute the stationary distribution over reachable states, $P_\infty(\theta)$.
@see Group::Pinfinity
**/
Group::StationaryDistribution() {
	PT[][] = Ptrans[N::ReachableIndices][N::ReachableIndices];
	PT = setdiagonal(PT,diagonal(PT-1.0));
	PT[0][]=1.0;
    Pinfinity[] = 0.0;
	switch (declu(PT,&l,&u,&p)) {
		case 0: println("*** Group ",pos);
				oxwarning("DDP Warning 20. stationary distribution calculation failed");
                Pinfinity[N::ReachableIndices] = .NaN;
				break;
		case 2:	println("*** Group ",pos);
				oxwarning("DDP Warning 20.\n Linear systems solution for stationary distribution returns code 2.\n May be unreliable.\n");
		case 1: Pinfinity[N::ReachableIndices] = solvelu(l,u,p,statbvector);
				break;
//		default: ;
		}
	}

Group::IncPtrans(et,h) {
    Ptrans[ et ][I::all[tracking]] = Ptrans[ et ][I::all[tracking]]  // memory leak
                                       + h;
    }
/** Draw $\theta$ from $P_\infty(\theta)$ for current $\gamma$.
@return state vector
@see DrawOne
**/
Group::DrawfromStationary() {	return ReverseState(DrawOne(Pinfinity),tracking); }

/** .
@internal
**/
FETask::FETask() {
	GroupTask();
	span = onlyfixed;	left = SS[span].left;	right = SS[span].right;
	}

/** Set the fixed effect $\gamma_f$ segment of the task's state vector.
@internal
@param f index of fixed effect group

**/
RETask::SetFE(f) {

	state[fixl:fixr] = isint(f) ? ReverseState(f,onlyfixed)[fixl:fixr]
       				 : f[fixl:fixr];
    SyncStates(fixl,fixr);
    I::f = I::all[onlyfixed];
	}
	
/** .
@internal
**/
RETask::RETask(caller) {
	GroupTask(caller);
	span = onlyrand;	left = SS[span].left;	right = SS[span].right;
    fixl = SS[onlyfixed].left;
    fixr = SS[onlyfixed].right;
	}

/** Set fixed and random effect segment of state vector for task.
@internal

@param f fixed effect group index
@param r random effect group index.

This calls SyncStates and `I::Set`()

**/
RETask::SetRE(f,r) {
    state[left:right] = 0;
    SetFE(f);
	state += ReverseState(r,onlyrand);
    SyncStates(left,right);
    I::Set(state,TRUE);
	}

/** Compute density of current group $\gamma$ conditional on fixed effects.
**/
Group::Density(){
	curREdensity = 1.0;
	decl g=S[rgroup].X;
	do {
		if (isclass(States[g],"CorrelatedEffect")) {
			curREdensity *= States[g].block.pdf; //not correct yet
            println("!!! Correct Correlated Effects ",g," ",curREdensity);
			g -= States[g].block.N;
			}
		else {
            States[g]->Distribution();
			curREdensity *= States[g].pdf[CV(States[g])];   //extend to GroupEffect
			--g;
			}
		} while (g>=S[rgroup].M);
	gdist[find][rind] = curREdensity;
	return curREdensity;
	}
	
/** .
@internal
**/
UpdateDensity::UpdateDensity() {
	RETask();
	}

/** Update density of $\gamma_r$.
@internal
**/
UpdateDensity::Run() {	I::curg->Density();	}

DPDebug::DPDebug() {	ThetaTask(tracking);     }

/** Print the table of value functions and choice probabilities for all fixed effect groups.
@param ToScreen  TRUE means output is displayed.
@param aM	address to return matrix<br>0, do not save
@param MaxChoiceIndex FALSE = print choice probability vector (default)<br>TRUE = only print index of choice with max probability.  Useful when the full action matrix is very large.
@param TrimTerminals TRUE means states marked as `Bellman::Type` terminal are deleted
@param TrimZeroChoice TRUE means states with no choice are deleted

@example
Print out everthing to the screen once model is solved:
<pre>
   &vellip;
   CreateSpaces();
   meth = new ValueIteration();
   DPDebug::outAllV();
   meth->Solve();
</pre>
Store everthing to a matrix without printing to the screen:
<pre>
   decl av;
   &vellip;
   DPDebug::outAllV(FALSE,&av);
</pre>
If after solving the model you want to save the output table in an external file with labels for the columns use Ox's <code>savemat()</code>
routine and `DPDebug::SVlabels`:
<pre>
   &vellip;
   meth->Solve();
   savemat("v.dta",av,DPDebug::SVlabels);
</pre>
Print to screen only highest-probability choice index (not all probabilities) for non-terminal states with a real choice:
<pre>
   DPDebug::outAllV(TRUE,FALSE,TRUE,TRUE,TRUE);
</pre>

the screen once model is solved:

</dd>
The tables for individual fixed effect groups are concatenated together if <code>aM</code> is an address.
On the screen the tables are printed out separately for each fixed effect.

@see DPDebug::outV
**/
DPDebug::outAllV(ToScreen,aM,MaxChoiceIndex,TrimTerminals,TrimZeroChoice) {
	rp = new SaveV(ToScreen,aM,MaxChoiceIndex,TrimTerminals,TrimZeroChoice);
    OutAll = TRUE;
    }

/**For the current fixed-effect group, print the value function $EV(\theta)$ and choice probability $P^\star(\alpha;\epsilon,\eta,\theta)$ or index of max $P^\star$.
@param ToScreen  TRUE means output is displayed.
@param aM	address to return matrix<br>0, do not save
@param MaxChoiceIndex FALSE = print choice probability vector (default)<br>TRUE = only print index of choice with max probability.  Useful when the full action matrix is very large.


The columns of the matrix are:
<DD><pre>
StateIndex IsTerminal Aindex EndogenousStates t REIndex FEIndex EV &Rho;(&alpha;)'
</pre>
and
<pre>
Column                Definition
---------------------------------------------------------------------------------------
StateIndex            Integer index of the state in the endogenous state space &Theta;
IsTerminal            The state is terminal, see `StateVariable::TermValues`
Aindex                The index of the feasible action set, A(&theta;)
EndogenousStates      The value of the endogenous state variables at &theta;
t                     The time variable, see `DP::SetClock` and `I::t`.
REIndex               The index into the random effect state space
FEIndex               The index into the fixed effect state space
EV                    EV(&theta;) integrating over any exogenous (&epsilon;) or
                      semi-exogenous (&eta;) state variables.
Pinf                  The stationary distribution if the clock is ergodic
P*                    The conditional choice probability vector (transposed into a column
                      and expanded out to match the full potential action matrix.
                      (or if <code>MaxChoiceIndex</code> just the index with the highest
                      choice probability.
</pre>
</DD>

@comments
When a solution `Method::Volume` is set to <code>LOUD</code> this function is called after each
fixed effect group is complete.

@see DPDebug::outAllV

**/
DPDebug::outV(ToScreen,aM,MaxChoiceIndex,TrimTerminals,TrimZeroChoice) {
    outAllV(ToScreen,aM,MaxChoiceIndex,TrimTerminals,TrimZeroChoice);
    //OutAll = FALSE;  May 2022:  Not sure why this was here.
    DPDebug::RunOut();
	}

/** . @internal **/
DPDebug::RunOut() {
	rp.nottop = FALSE;
    decl hder = "\n     Value of States" + (Flags::IsErgodic ? ", Ergodic Distn, and " : " and ")+"Choice Probabilities ";
    if (N::G>1) hder += "\n     Fixed Group Index(f): "+sprint(I::f)+". Random Group Index(r): "+sprint(I::r)+"\n"+sprint(div);
	if (rp.ToScreen) println(hder);
    else if (isfile(logf)) fprintln(logf,hder);
	rp -> Traverse();
	if (rp.ToScreen) println(div,"\n");	else if (isfile(logf)) fprintln(logf,div,"\n");	
    ++ndone;
	if (ndone==N::G) {   //last or only group, so delete rp and reset.
        delete rp;
        OutAll = FALSE;
        ndone = Zero;
        }
    }

/** . @internal **/
DPDebug::outAutoVars() {
	decl rp = new OutAuto();
	rp -> Traverse();
	delete rp;
	}

/** . @internal **/
DPDebug::Initialize() {
    sprintbuffer(16 * 4096);
	prtfmt0 = array("%8.0f")|Labels::Sfmts[1:2]|Labels::Sfmts[3+S[endog].M:3+S[clock].M]|"%6.0f"|"%6.0f"|"%16.6f";
	Vlabel0 = {"    Indx","T","A"}|Labels::Vprt[svar][S[endog].M:S[clock].M]|"     r"|"     f"|"       EV      |";
    if (Flags::IsErgodic) {
        Vlabel0 |= "  Erg.Distn  |";
        prtfmt0 |= "%11.7f";
        }
    ndone=Zero;
	}

/** . @internal **/
DPDebug::outSVTrans(...
    #ifdef OX_PARALLEL
    va
    #endif
) {
	decl rp = new SVT(va);
	rp -> Traverse();
	delete rp;
    }

/** . @internal **/
SVT::SVT(Slist){
    DPDebug();
    this.Slist = Slist;
    }

/** . @internal **/
SVT::Run() {
    decl s,feas,prob;
    #ifdef DEBUG
        if (isfile(logf)) fprint(logf,"State ","%8.0f","%c",Labels::Vprt[svar][S[endog].M:S[clock].M],state[S[endog].M:S[clock].M]');
    #endif
    foreach(s in Slist) {
		if (isclass(s,"Coevolving")) s = s.block;
		[feas,prob] = s -> Transit(); //TTT
        #ifdef DEBUG
            if (isfile(logf)) fprintln(logf,"     State: ",s.L,"%r",{Alpha::aL1}|Alpha::Rlabels[I::curth.Aind],feas|prob);
        #endif
		}
    }

/** Save the value function as a matrix and/or print.
@param ToScreen  TRUE, print to output (default)
@param aM  = 0 do not save to a matrix (default) <br>address to save too
@param MaxChoiceIndex = FALSE  print choice probability vector (default)<br>= TRUE only print index of choice with max probability.  Useful when the full action matrix is very large.
**/
SaveV::SaveV(ToScreen,aM,MaxChoiceIndex,TrimTerminals,TrimZeroChoice) {
    DPDebug::DPDebug();
	this.ToScreen = ToScreen;
    this.MaxChoiceIndex = MaxChoiceIndex;
    this.TrimTerminals = TrimTerminals;
    this.TrimZeroChoice = TrimZeroChoice;
	SVlabels = Vlabel0 | (MaxChoiceIndex ? {"index " | " maxP* " | " sum(P) "} : "Choice Probabilities:");
    prtfmt  = prtfmt0;
    if (MaxChoiceIndex)
        prtfmt  |= "%5.0f" | "%9.6f" | "%15.6f";
    else{
        for(decl i=0;i<N::A;++i) prtfmt |= "%9.6f";
        prtfmt |= "%15.6f";
        }
	if (( !isint(this.aM = aM) )) this.aM[0] = <>;
	nottop = FALSE;
	}

/** . @internal **/	
SaveV::Run() {
    decl ai=I::curth.Aind;
	if ((TrimTerminals && I::curth.Type>=TERMINAL) || (TrimZeroChoice && N::Options[I::curth.Aind]<=1) ) return;
    decl mxi, p, oned=isclass(I::curth,"OneDimensionalChoice");
	stub=I::all[tracking]~I::curth.Type~ai~state[S[endog].M:S[clock].M]';
    decl pv = I::curth->GetPandV();
    p = columns(pv)==rows(NxtExog[Qprob])
            ?  /* ExpandP (ai, */ pv*NxtExog[Qprob] /*)*/
            :  /* ExpandP(ai,  */ pv /*)*/ ;
    mxi = maxcindex(p);
    oxprintlevel(-1);
    r =stub~I::r~I::f~I::curth.EV; //N::VV[I::later][I::all[iterating]]
    if (Flags::IsErgodic) r ~= I::curg.Pinfinity[I::all[tracking]];
    if (MaxChoiceIndex) {
        mxi = double(maxcindex(p));
        r ~= mxi~p[mxi]~sumc(p);
        }
    else
        r ~= p' ;
	if (oned && I::curth.solvez ) r ~= I::curth->Getz()[]';
	if (!isint(aM)) aM[0] |= r;
    oxprintlevel(1);
	s = (nottop)
		? sprint("%cf",prtfmt,r)
		: sprint("%c",oned ? SVlabels | "      z* " : SVlabels,"%cf",prtfmt,r);
	if (ToScreen) print(s[1:]); else if (isfile(logf)) fprint(logf,s[1:]);
	nottop = TRUE;
	}

OutAuto::OutAuto(){    DPDebug::DPDebug(); }

/** . @internal **/
OutAuto::Run() { I::curth->AutoVarPrint1(this);  }	

/** .
**/
RandomEffectsIntegration::RandomEffectsIntegration() {	RETask(); 	}

/** Integrate over $\gamma_r$.	
@param path Observed path to integrate likelihood over random effects for.
@return array {L,flat}, where L is the path objective, integrating over random &gamma;
and flat is the
integrated flat output of the path.
**/
RandomEffectsIntegration::Integrate(path) {
	this.path = path;
	L = 0.0;
    flat = 0;
	loop();
	return {L,flat};
	}
	
/** . @internal **/
RandomEffectsIntegration::Run() {
    path.rcur = I::r;  //Added Dec. 2016
    if (Flags::UpdateTime[AfterRandom ]) ETT->Transitions(I::curg.state);
    L += path->TypeContribution(curREdensity);
    }

/** Open data log with timestamp.
**/
Data::SetLog() {
    Volume = SILENT;
    lognm = replace(Version::logdir+"Data"," ","")+".log";
    logf = fopen(lognm,"av");
    fprintln(logf,"**** ",Version::tmstmp," ****");
    }
