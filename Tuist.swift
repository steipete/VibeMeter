import ProjectDescription

let config = Config(
    generationOptions: .options(
        staticSideEffectsWarningTargets: .all,
        enforceExplicitDependencies: true
    )
)
