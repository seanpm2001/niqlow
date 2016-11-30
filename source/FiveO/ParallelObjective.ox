/** Client and Server classes for parallel optimization using CFMPI.**/
#include "ParallelObjective.h"

/** Set up MPI Client-Server support for objective optimization.
@param obj `Objective' to parallelize
@param DONOTUSECLIENT TRUE (default): client node does no object evaluation<br>FALSE after putting servers to work Client node does one evaluation.
**/
ParallelObjective(obj,DONOTUSECLIENT) {
	if (isclass(obj.p2p)) {oxwarning("CFMPI Warning 01.\n"+" P2P object already exists for "+obj.L+". Nothing changed.\n"); return;}
	obj.p2p = new P2P(DONOTUSECLIENT,new ObjClient(obj),new ObjServer(obj));
	}

ObjClient::ObjClient(obj) { this.obj = obj;    }

ObjClient::Execute() {    }

ObjServer::ObjServer(obj) {	
    this.obj = obj;	
    basetag = P2P::STOP_TAG+1;
    iml = obj.NvfuncTerms;
    Nstruct = obj.nstruct;
    }

/** Wait on the objective client.
**/
ObjServer::Loop(nxtmsgsz) {
    Nfree = nxtmsgsz;   //current free param length sent from algorithm
    if (Volume>QUIET) println("ObjServer server ",ID," Nfree= ",Nfree);
    Server::Loop(Nfree);
    Recv(ANY_TAG);                      //receive the ending parameter vector
    obj->Encode(Buffer[:Nstruct-1]);   //encode it.
    }

/** Do the objective evaluation.
Receive structural parameter vector and `Objective::Encode`() it.
Call `Objective::vfunc`().
@return Nstruct (max. length of next expected message);
**/
ObjServer::Execute() {
	obj->Decode(Buffer[:obj.nfree-1]);
	Buffer = obj.cur.V[] = obj->vfunc();
    if (Volume>QUIET) println("Server Executive: ",ID," vfunc[0]= ",Buffer[0]);
	return Nstruct;
	}

CstrServer::CstrServer(obj) { ObjServer(obj);	}

SepServer::SepServer(obj) { ObjServer(obj);	}
	
CstrServer::Execute() {
	obj->Encode(Buffer);
	obj->Lagrangian(0);
	return rows(Buffer = obj.cur->Vec());
	}

/** Separable objective evaluations.
**/
SepServer::Execute() {
	obj.Kvar.v = imod(Tag-basetag,obj.K);
	obj->Encode(Buffer,TRUE);		
	Buffer = obj.Kvar->PDF() * obj->vfunc();
	return obj.NvfuncTerms;
	}
