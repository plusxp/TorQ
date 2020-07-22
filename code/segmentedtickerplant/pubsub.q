// Pub/sub utilities for segmented tp process
// Functionality for clients to subscribe to all tables or a subset
// Includes option for subsrcibe to apply filters to received data

\d .stpps

// List of pub/sub tables, populated on startup
t:`

// Handles to publish all data
subrequestall:enlist[`]!enlist ()

// Handles and conditions to publish filtered data
subrequestfiltered:([]tbl:`$();handle:`int$();filts:();columns:())

// Function to send end of period messages to subscribers
// Assumes that .u.endp has been defined on the client side
endp:{
  (neg raze union/[value subrequestall;exec handle from .stpps.subrequestfiltered])@\:(`.u.endp;x;y);
 };

// Function to send end of day messages to subscribers      
// Assumes that .u.end has been defined on the client side   
end:{
  (neg raze union/[value subrequestall;exec handle from .stpps.subrequestfiltered])@\:(`.u.end;x;y);
 };

suball:{
  delhandle[x;.z.w];
  add[x];
  :(x;schemas[x]);
 };

subfiltered:{[x;y]
  delhandlef[x;.z.w];
  if[11=type y;selfiltered[x;y]];
  if[99=type y;addfiltered[x;y]];
  :(x;schemas[x]);
 };

// Add handle to subscriber in sub all mode
add:{
  if[not (count subrequestall x)>i:subrequestall[x]?.z.w;
    subrequestall[x],:.z.w];
 };

// Add handle to subscriber in sub filtered mode
// Where clause and column filters are parsed before adding to subrequestfiltered table
addfiltered:{[x;y]
  filts:$[null y[x]`filts;();enlist parse string y[x]`filts];
  columns:$[null y[x]`columns;();c!c:raze parse string y[x]`columns];
  `.stpps.subrequestfiltered upsert (x;.z.w;filts;columns);
 };

// Add handle for subscriber using old API (filter is list of syms)
selfiltered:{[x;y]
  filts:enlist (in;`sym;enlist y);
  `.stpps.subrequestfiltered upsert (x;.z.w;filts;());
 };

upd:{[t;x]
  x:updtab[t]@x;
  t insert x;
  :x;
 };

pub:{[t;x]
  if[count x;
    if[count h:subrequestall[t];-25!(h;(`upd;t;x))];
    if[t in subrequestfiltered`tbl;
      {[t;x]data:?[t;x`filts;0b;x`columns];-25!((),x`handle;(`upd;t;data))}
      [t;]each select handle,filts,columns from subrequestfiltered where tbl=t
    ];
  ];
 };

// Functions to add columns on updates
updtab:enlist[`]!enlist {(enlist(count first x)#.z.p),x}

// Remove handle from subscription meta
delhandle:{[t;h]
  @[`.stpps.subrequestall;t;except;h];
 };

delhandlef:{[t;h]
  delete from  `.stpps.subrequestfiltered where tbl=t,handle=h;
 };

// Remove all handles when connection closed
closesub:{[h]
  delhandle[;h]each t;
  delhandlef[;h]each t;
 };

.z.pc:{[f;x] f@x; closesub x}@[value;`.z.pc;{{}}]

\d .

// Function called on subscription
// Subscriber will call with null y parameter in sub all mode
// In sub filtered mode, y will contain tables to subscribe to and filters to apply
.u.sub:{[x;y]
  if[not x in .stpps.t;
    .lg.e[`rdb;"Table ",string[x]," not in list of stp pub/sub tables"];
    :()
  ];
  if[y~`;:.stpps.suball[x]];
  if[not y~`;:.stpps.subfiltered[x;y]]
 };
