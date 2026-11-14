function run_synthetic_batch(numBands)
% Run the fixed synthetic experiment through the shared Paper1 core.
if nargin<1, numBands=2; end
main_Paper1('synthetic','',1,numBands);
end
