@{
    IncludeDefaultRules = $true
    Severity            = @("Error", "Warning")
    ExcludeRules        = @(
        "PSUseOutputTypeCorrectly",
        "PSAvoidUsingUserNameAndPassWordParams",
        "PSAvoidUsingPlainTextForPassword"
    )
}
