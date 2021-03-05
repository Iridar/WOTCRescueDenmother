class XComGameState_DenmotherHealingProject extends XComGameState_HeadquartersProjectHealSoldier;

var config(Denmother) float HealingRateMultiplier;

function int CalculateWorkPerHour(optional XComGameState StartState = none, optional bool bAssumeActive = false)
{
	return float(super.CalculateWorkPerHour(StartState, bAssumeActive)) * HealingRateMultiplier;
}