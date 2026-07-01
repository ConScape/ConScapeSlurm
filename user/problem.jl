# Problem definition

# This is the only code you need to edit
function problem(args...)
    s = settings(args...)
    ## Define connectivity
    alpha = s["alpha"]::Float64
    theta = s["theta"]::Float64
    # Define a distance transformation
    movement = RandomisedShortestPath(ExpectedCost();
        distance_transformation = ExpMinusAlpha(alpha),
        theta,
    )

    # Define measures
    measures = (;
        fh =                FunctionalHabitat(),
        betk =              Betweenness(QualityAndProximityWeighted()),
        sens_sum_perm =     SensitivityAnalysis(; wrt=StepCostToLikelihood(), type=Sensitivity(), metric=Summation()),
        sens_sum_quality =  SensitivityAnalysis(; wrt=Quality(), type=Sensitivity(), metric=Summation()),
    )

    ## Specify the problem
    solver = ConScape.ColumnSolver()
    ConScapeProblem(; movement, measures, solver)
end