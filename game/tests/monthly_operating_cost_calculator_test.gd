extends Node

const MonthlyOperatingCostCalculatorScript = preload(
	"res://scripts/core/monthly_operating_cost_calculator.gd"
)


func _ready() -> void:
	DataRepository.load_all()
	var calculator = MonthlyOperatingCostCalculatorScript.new()
	_test_zero_population_uses_fixed_expense(calculator)
	_test_population_costs_use_frozen_values(calculator)
	_test_negative_population_is_rejected(calculator)
	_test_contract(calculator)
	print("Monthly operating cost calculator: OK")
	get_tree().quit(0)


func _test_zero_population_uses_fixed_expense(calculator) -> void:
	var result: Dictionary = calculator.calculate(0, 0, 0)
	assert(result.get("status") == "ready")
	assert(int(result.get("fixed_expense", 0)) == 88)
	assert(int(result.get("total", 0)) == 88)
	assert(result.get("period") == "month")
	assert(result.get("legacy_daily_formula_used") == false)
	assert(result.get("legacy_weekly_formula_used") == false)


func _test_population_costs_use_frozen_values(calculator) -> void:
	var result: Dictionary = calculator.calculate(3, 4, 2)
	assert(result.get("status") == "ready")
	assert(int(result.get("slave_cost", 0)) == 15)
	assert(int(result.get("gladiator_cost", 0)) == 80)
	assert(int(result.get("beast_cost", 0)) == 20)
	assert(int(result.get("total", 0)) == 203)
	assert(result.get("rule_source") == "DataRepository.monthly_operating_costs")


func _test_negative_population_is_rejected(calculator) -> void:
	var result: Dictionary = calculator.calculate(-1, 0, 0)
	assert(result.get("status") == "rejected")
	assert(result.get("reason") == "negative_population_count")
	assert(int(result.get("total", -1)) == 0)


func _test_contract(calculator) -> void:
	var contract: Dictionary = calculator.get_contract()
	assert(contract.get("period") == "month")
	assert(int(contract.get("fixed_expense", 0)) == 88)
	assert(int(contract.get("slave_maintenance", 0)) == 5)
	assert(int(contract.get("gladiator_maintenance", 0)) == 20)
	assert(int(contract.get("beast_maintenance", 0)) == 10)
	assert(contract.get("legacy_daily_formula_allowed") == false)
	assert(contract.get("legacy_weekly_formula_allowed") == false)
	assert(contract.get("save_version_change_required") == false)
