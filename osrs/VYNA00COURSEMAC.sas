


%macro colname(dsn=,pos=); 
  %local dsid var; 
	%let dsid = %sysfunc(open(&dsn));  
	  %if &dsid %then %do;    
 		%let var=%sysfunc(varname(&dsid,&pos));
 		%let dsid = %sysfunc(close(&dsid));
	  %end;  
	&var
%mend colname;

%macro GetValue(mac=, item=);
 %let prs = %sysfunc(prxparse(m/\b&item=/i));
  %if %sysfunc(prxmatch(&prs, &&&mac)) %then %do;
    %let prs = %sysfunc(prxparse(s/.*\b&item=([^ ]+).*/$1/i));
    %let return_val = %sysfunc(prxchange(&prs, 1, &&&mac));
      &return_val
  %end;
  %else %do;
    %put ERROR: Cannot find &item!;
  %end;
%mend GetValue;

%macro incConvert(incDSName=,projectionNodes=,outNodes=,outLinks=);
  proc iml;
 	use &incDSName.;
   	  read all var _NUM_ into X[rowname=%colname(dsn=&incDSName.,pos=1) colname=colNames]; 
 	close &incDSName.;

	start incMatrix2Links(incMatrix,rowNames,colNames);
		R = repeat(t(1:nrow(incMatrix)), 1, ncol(incMatrix));  /* row index */
   		C = repeat(1:ncol(incMatrix), nrow(incMatrix));        /* col index */

		incLong = colvec(R) /*from*/ || colvec(C) /*to*/ || colvec(incMatrix) /*weight*/;

		keepIdx = loc(incLong[,3]>0);  
		if ncol(keepIdx)>0 then incLong = incLong[keepIdx,]; 

		from=rowNames[incLong[,1]]; /* convert position index to character row name */
		to=colNames[incLong[,2]];   /* convert position index to character col name */
		weight=incLong[,3];

  		create &outLinks. var {from to weight};
   	 	   append;
  		close &outLinks.;
	finish;

	call incMatrix2Links(X,%colname(dsn=&incDSName.,pos=1),colNames);


	%if %length(&projectionNodes) > 0 %then %do;

	   %if %length(&outNodes)=0 %then %do;
	     %let outNodes=WORK._PROJNODES_;
	   %end;

	   	  start incMatrix2Nodes(nodes,rowNames,colNames);
		  	if upcase(strip(compress(nodes)))='ROWS' then do;
  	  	      node=rowNames//t(colNames); /* append rowName and colName vectors */
	  	      nObs = nrow(rowNames);
		  	end;
		  	else if upcase(strip(compress(nodes)))='COLS' then do;
	  	      node=t(colNames)//rowNames; /* append colName and rowName vectors */
	  	      nObs = nrow(t(colNames));
		  	end;

		  	partitionFlag=j(nrow(node),1,.); /* initialize partition flag vector to missing */

		  	partitionFlag[1:nObs]=1;
  		  	partitionFlag[loc(missing(partitionFlag))]=0; 

  		  	create &outNodes. var {node partitionFlag};
   	 	       append;
  		  	close &outNodes.;
	   	 finish;

	   	 call incMatrix2Nodes(&projectionNodes,%colname(dsn=&incDSName.,pos=1),colNames);
	%end;
  quit;
%mend;



