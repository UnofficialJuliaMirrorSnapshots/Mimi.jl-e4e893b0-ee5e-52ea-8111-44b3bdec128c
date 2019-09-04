@defcomp grosseconomy begin
    regions = Index()                           #Note that a regional index is defined here

    YGROSS  = Variable(index=[time, regions])   #Gross output
    K       = Variable(index=[time, regions])   #Capital
    depk_var  = Variable(index=[regions])         #dummy output for testing of layered histograms
    share_var = Variable()                      #dummy output for testing of histogram

    l       = Parameter(index=[time, regions])  #Labor
    tfp     = Parameter(index=[time, regions])  #Total factor productivity
    s       = Parameter(index=[time, regions])  #Savings rate
    depk    = Parameter(index=[regions])        #Depreciation rate on capital - Note that it only has a region index
    k0      = Parameter(index=[regions])        #Initial level of capital
    share   = Parameter()                       #Capital share

    function run_timestep(p, v, d, t)
    # Note that the regional dimension is defined in d and parameters and variables are indexed by 'r'

        # Define an equation for K
        for r in d.regions
            if is_first(t)
                v.K[t,r] = p.k0[r]
                v.depk_var[r] = p.depk[r]
                v.share_var = p.share
            else
                v.K[t,r] = (1 - p.depk[r])^5 * v.K[t-1,r] + v.YGROSS[t-1,r] * p.s[t-1,r] * 5
            end
        end

        # Define an equation for YGROSS
        for r in d.regions
            v.YGROSS[t,r] = p.tfp[t,r] * v.K[t,r]^p.share * p.l[t,r]^(1-p.share)
        end
    end
end