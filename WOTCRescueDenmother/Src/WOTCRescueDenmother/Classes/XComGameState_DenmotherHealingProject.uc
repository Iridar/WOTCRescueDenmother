class XComGameState_DenmotherHealingProject extends XComGameState_HeadquartersProjectHealSoldier config(Denmother);

var config float HealingRateMultiplier;

function int CalculateWorkPerHour(optional XComGameState StartState = none, optional bool bAssumeActive = false)
{
	return float(super.CalculateWorkPerHour(StartState, bAssumeActive)) * HealingRateMultiplier;
}