using Mimi

# Define a simple component
# =========================

@defcomp component1 begin

    # First define the state this component will hold
    savingsrate = Parameter()

    # Second, define the (optional) init function for the component
    function init(p, v, d)
    end

    # Third, define the run_timestep function for the component
    function run_timestep(p, v, d, t)
    end

end


# Create a model uses the component
# =================================

@defmodel begin

    m = Model()

    component(component1)
end

# Run model
# =========

run(m)

# Explore the model variables and parameters with the explorer UI
# =================================

explore(m)

# Access the variables in the model
# =================================
