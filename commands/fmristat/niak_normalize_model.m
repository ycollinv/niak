function [model_n,opt] = niak_normalize_model (model, opt)
% Prepare a model for regression analysis: interaction, selection, projection, etc
%
% SYNTAX:
% [MODEL_N,OPT] = NIAK_NORMALIZE_MODEL (MODEL,OPT).
% _________________________________________________________________________________
% INPUTS:
%
% MODEL 
%   (structure) with the following fields:
%    
%   X   
%      (matrix M*K) the covariates (observations x covariates)
%
%   Y 
%      (matrix M*N, default []) the data (observations x units)
% 
%   LABELS_X
%      (cell of strings 1xM) LABELS_X{M} is the label of the Mth observation.
%
%   LABELS_Y
%      (cell of strings 1*K) LABELS_Y{K} is the label of the Kth covariate
%
% OPT
%   (structure) with the following fields:
%
%   CONTRAST
%      (structure, with arbitray fields <NAME>, which needs to correspond to the 
%      label of one column in the file FILES_IN.MODEL.GROUP) The fields found in 
%      CONTRAST will determine which covariates enter the model:
%
%      <NAME>
%         (scalar) the weight of the covariate NAME in the contrast.
% 
%   INTERACTION
%      (structure, optional) with multiple entries and the following fields :
%          
%      LABEL
%         (string) a label for the interaction covariate.
%
%      FACTOR
%         (cell of string) covariates that are being multiplied together to build the
%         interaction covariate.  There should be only one covariate associated with 
%         each label.
%
%      FLAG_NORMALIZE_INTER
%         (boolean,default true) if FLAG_NORMALIZE_INTER is true, the factor of interaction 
%         will be normalized to a zero mean and unit variance before the interaction is 
%         derived (independently of OPT.<LABEL>.GROUP.NORMALIZE below.
%
%   PROJECTION
%      (structure, optional) with multiple entries and the following fields :
%
%      SPACE
%         (cell of strings) a list of the covariates that define the space to project 
%         out from (i.e. the covariates in ORTHO, see below, will be projected 
%         in the space orthogonal to SPACE).
%
%      ORTHO
%         (cell of strings) a list of the covariates to project in the space orthogonal
%         to SPACE (see above).
%
%   NORMALIZE_X
%      (structure or boolean, default true) If a boolean and true, all covariates of the 
%      model are normalized to a zero mean and unit variance. If a structure, the 
%      fields <NAME> need to correspond to the label of a column in the 
%      file FILES_IN.MODEL.GROUP):
%
%      <NAME>
%         (arbitrary value) if <NAME> is present, then the covariate is normalized
%         to a zero mean and a unit variance. 
%
%   NORMALIZE_Y
%      (boolean, default false) If true, the data is corrected to a zero mean and unit variance,
%      in this case across subjects.
%
%   FLAG_INTERCEPT
%      (boolean, default true) if FLAG_INTERCEPT is true, a constant covariate will be
%      added to the model.
%
%   SELECT
%      (structure, optional) with multiple entries and the following fields:           
%
%      LABEL
%         (string) the covariate used to select entries *before normalization*
%
%      VALUES
%         (vector, default []) a list of values to select (if empty, all entries are retained).
%
%      MIN
%         (scalar, default []) only values higher (or equal) than MIN are retained.
%
%      MAX
%         (scalar, default []) only values lower (or equal) than MAX are retained. 
%
%   LABELS_X
%      (cell of strings, default {}) The list of entries (rows) used 
%      to build the model (the order will be used as well). If left empty, 
%      all entries are used (but they are re-ordered based on alphabetical order). 
%      Contrary to MODEL.LABELS_X, the labels listed in OPT.LABELS_X need to be unique. 
%      For example, OPT.LABELS_X = { 'motion' , 'confounds' }; will first put all the 
%      covariates labeled 'motion' in the model and then all the covariates labeled 
%      'confounds', regardless of their numbers.
%
%_________________________________________________________________________________________
% OUTPUTS:
%
%   MODEL_N
%      (structure) Same as MODEL after the specified normalization (and generation of
%      covariates) procedure was applied. An additional field is added with a vectorized
%      version of the contrast:
% 
%      C
%         (vector 1*K) C(K) is the contrast associated with the covariate MODEL_N.X(:,K)
%
% ________________________________________________________________________________________
% SEE ALSO:
% NIAK_PIPELINE_GLM_CONNECTOME
%
% _________________________________________________________________________________________
% COMMENTS:
%
% In the selection process, if more than covariate are associated with OPT.SELECT.LABEL, 
% the final selection will be the intersection of all selections performed with individual
% covariates associated with the label.
%
% Copyright (c) Pierre Bellec, Jalloul Bouchkara
%               Centre de recherche de l'institut de Gériatrie de Montréal
%               Département d'informatique et de recherche opérationnelle
%               Université de Montréal, 2012
% Maintainer : pierre.bellec@criugm.qc.ca
% See licensing information in the code.
% Keywords : general linear model

%% Check the model
list_fields   = { 'x' , 'y' , 'labels_x' , 'labels_y' };
list_defaults = { NaN , []  , NaN        , NaN        };
model = psom_struct_defaults(model,list_fields,list_defaults);

%% Check the options
list_fields   = { 'select' , 'contrast' , 'projection' , 'flag_intercept' , 'interaction' , 'normalize_x' , 'normalize_y' , 'labels_x' };
list_defaults = { struct   , struct()   , struct       , true             , {}            , true          , false         , {}         };
if nargin > 1
   opt = psom_struct_defaults(opt,list_fields,list_defaults);
else
   opt = psom_struct_defaults(struct,list_fields,list_defaults);
end
if isempty(opt.labels_x)
    opt.labels_x = unique(model.labels_x);
end

%% Reorder (and reduce) the model using opt.labels_x 
if length(unique(opt.labels_x))~=length(opt.labels_x)
    error('The labels provided in OPT.LABELS_X should be unique')
end
[mask_x,ind_m] = ismember(opt.labels_x,model.labels_x) ; 
ind_err_x = find(mask_x == 0);
for num_ex = 1:length(ind_err_x)
    warning('The following specified observation was not found in the model : %s',labels_x{ind_err_x(num_ex)});
end
ind_m = ind_m(ind_m~=0);

labx_tmp = {};
x_tmp = [];
y_tmp = [];
model.labels_x = model.labels_x(:);
model.labels_y = model.labels_y(:);

for num_m = 1:length(ind_m)
    mask_tmp = ismember(model.labels_x,model.labels_x{ind_m(num_m)});
    labx_tmp = [ labx_tmp ; model.labels_x(mask_tmp)];
    x_tmp = [x_tmp ; model.x(mask_tmp,:)];
    y_tmp = [y_tmp ; model.y(mask_tmp,:)];
end

model.x = x_tmp;
model.y = y_tmp;
model.labels_x = labx_tmp;

% Optional : select a subset of entries
if ~isempty(opt.select)
    for num_s = 1:length(opt.select)
        if ~isfield(opt.select(num_s),'label')
           continue
        end
        opt_s = psom_struct_defaults(opt.select(num_s),{'label','values','min','max'},{NaN,[],[],[]});
        mask = true([size(model.x,1) 1]);
        ind = find(ismember(model.labels_y,opt_s.label));
        if ~isempty(opt_s.values)
           mask = min(ismember(model.x(:,ind),opt_s.values),[],2);
        end
        if ~isempty(opt_s.min)
           mask = mask&min(model.x(:,ind)>opt_s.min,[],2);
        end
        if ~isempty(opt_s.max)
           mask = mask&min((model.x(:,ind)<opt_s.max),[],2);
        end
        model.x = model.x(mask,:);
        if ~isempty(model.y)
           model.y = model.y(mask,:);
        end
        model.labels_x = model.labels_x(mask);
     end
end

% Optional: Compute the interaction
if ~isempty(opt.interaction)   
    x_inter = model.x;
    for num_i = 1:length(opt.interaction)
       if iscellstr(opt.interaction(num_i).factor) && (size((opt.interaction(num_i).factor),2) > 1)      
          for num_u = 1:size((opt.interaction(num_i).factor),2)
              factor = opt.interaction(num_i).factor{num_u};
              mask   = strcmpi(factor, model.labels_y) ;
              ind    = find(mask == 1);
              if length(ind)>1
                  error('Attempt to define an interaction term using the label %s, which is associated with more than one covariate',factor)
              end
              if ~isfield(opt.interaction(num_i),'flag_normalize_inter')||opt.interaction(num_i).flag_normalize_inter
                  opt_m.type = 'mean_var';
                  fac_ind = niak_normalize_tseries(model.x(:,ind));
              else
                  fac_ind = model.x(:,ind);
              end
              if num_u == 1 
                  col_inter = fac_ind;
              else              
                  col_inter = fac_ind.*col_inter ;
              end 
          end
          % Optional: normalization of interaction covariates   
          if ~isfield(opt.interaction(num_i),'flag_normalize_inter')||opt.interaction(num_i).flag_normalize_inter
             opt_m.type = 'mean_var';
             col_inter = niak_normalize_tseries(col_inter,opt_m);
          end
          % Check if the column exist before adding a new column 
          model.labels_y{end+1} = opt.interaction(num_i).label;
          x_inter = [x_inter col_inter];
      else 
          error('factor should be a cell of string and choose more than 1 factor ');
      end
      model.x=x_inter ;
   end
end 

% Optional: additional intercept covariate
if opt.flag_intercept
    mask = strcmpi('intercept',model.labels_y);
    if ~any(mask) ||  isempty(mask) % mask =0 or when the model.labels_y= {} !
        model.labels_y = [{'intercept'}; model.labels_y(:)];
    end 
    if ~isempty(model.x)
        model.x = [ones([size(model.x,1) 1]) model.x];
    else
        model.x = ones(length(model.labels_x),1); 
    end       
end

%% Build the contrast vector and extract the associated covariates
list_cont = fieldnames(opt.contrast);
if opt.flag_intercept&&~isfield(opt.contrast,'intercept')
    list_cont = [{'intercept'} ; list_cont(:)];
    opt.contrast.intercept = 0;
end
x_cont = zeros(size(model.x,1),length(list_cont));
model.c = zeros(length(list_cont),1);
for num_c = 1:length(list_cont)
    mask = strcmpi(list_cont{num_c},model.labels_y);
    if ~any(mask)
        error('Could not find the covariate %s listed in the contrast',list_cont{num_c});
    end
    x_cont(:,num_c) = model.x(:,mask);
    model.c(num_c) = opt.contrast.(list_cont{num_c});
end
model.x = x_cont;
model.labels_y = list_cont;

% orthogonalization of covariates
model = sub_normalize(model,opt);
if ~isempty(opt.projection)&&isfield(opt.projection(1),'space')
   for num_e = 1:length(opt.projection)  
       mask_space = ismember(model.labels_y,opt.projection(num_e).space);
       mask_ortho = ismember(model.labels_y,opt.projection(num_e).ortho);
       [B,E] = niak_lse(model.x(:,mask_ortho),model.x(:,mask_space));
       model.x(:,mask_ortho) = E ;
       % normalization of covariates (again)
       model = sub_normalize(model,opt);
    end
end

% Return
model_n = model;

%%%%%%%%%%%%%%%%%%
%% SUBFUNCTIONS %%
%%%%%%%%%%%%%%%%%%

function model = sub_normalize(model,opt)
%% Optional: normalization of covariates

if isbool(opt.normalize_x)&&opt.normalize_x
    opt_n.type = 'mean_var';  
    % because the normalization will give 0 il the nbr of rows = 1
    if size(model.x,1) ~= 1  
        model.x = niak_normalize_tseries(model.x,opt_n);
    end
else
    mask = ismember(model.labels_y,fieldnames(opt.normalize_x));
    model.x(:,mask) = niak_normalize_tseries(model.x(:,mask));
end
mask = ismember(model.labels_y,'intercept');
model.x(:,mask) = 1;

if opt.normalize_y && isfield ( model, 'y' ) &&  size(model.y,1) > 2   
    model.y = niak_normalize_tseries(model.y,opt_n);
end