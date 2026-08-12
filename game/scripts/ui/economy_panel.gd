extends VBoxContainer

var sponsor_ids: Array[String] = []
var loan_ids: Array[String] = []

@onready var back_button: Button = $Navigation/BackToFinca
@onready var status: Label = $Navigation/Status
@onready var scroll: ScrollContainer = $Scroll
@onready var summary: RichTextLabel = $Scroll/Content/Summary
@onready var sponsor_selector: OptionButton = $Scroll/Content/ContractRow/SponsorSelector
@onready var sign_button: Button = $Scroll/Content/ContractRow/SignContract
@onready var loan_selector: OptionButton = $Scroll/Content/LoanRow/LoanSelector
@onready var loan_button: Button = $Scroll/Content/LoanRow/TakeLoan
@onready var contracts: RichTextLabel = $Scroll/Content/Columns/Contracts
@onready var loans: RichTextLabel = $Scroll/Content/Columns/Loans
@onready var ledger: RichTextLabel = $Scroll/Content/Ledger


func _ready() -> void:
	back_button.pressed.connect(_return_to_finca)
	sign_button.pressed.connect(_on_sign_contract)
	loan_button.pressed.connect(_on_take_loan)
	sponsor_selector.item_selected.connect(_on_selection_changed)
	loan_selector.item_selected.connect(_on_selection_changed)
	EconomyManager.economy_changed.connect(_refresh)
	EconomyManager.contract_failed.connect(_show_error)
	EconomyManager.loan_failed.connect(_show_error)
	EconomyManager.bankruptcy_warning.connect(_on_bankruptcy_warning)
	GameState.resources_changed.connect(_refresh)
	_populate_options()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		_return_to_finca()
		get_viewport().set_input_as_handled()


func _return_to_finca() -> void:
	FincaHubController.show_finca()


func _populate_options() -> void:
	sponsor_selector.clear()
	sponsor_ids = EconomyManager.get_sponsor_ids()
	for sponsor_id in sponsor_ids:
		var data := EconomyManager.get_sponsor(sponsor_id)
		sponsor_selector.add_item("%s — fuera de demo" % str(data.get("name", sponsor_id)))
	loan_selector.clear()
	loan_ids = EconomyManager.get_loan_ids()
	for loan_id in loan_ids:
		var data := EconomyManager.get_loan_product(loan_id)
		loan_selector.add_item("%s — fuera de demo" % str(data.get("name", loan_id)))


func _on_sign_contract() -> void:
	_show_error(EconomyManager.PENDING_SPONSOR_REASON)


func _on_take_loan() -> void:
	_show_error(EconomyManager.PENDING_LOAN_REASON)


func _on_selection_changed(_index: int) -> void:
	_refresh()


func _on_bankruptcy_warning(_level: int, message: String) -> void:
	status.text = message


func _show_error(reason: String) -> void:
	status.text = reason


func _refresh() -> void:
	var data := EconomyManager.get_summary()
	var breakdown: Dictionary = data.get("monthly_operating_cost_breakdown", {})
	summary.text = (
		(
			"[b]TESORERÍA[/b]\nCosto operativo mensual: %d | Deuda legacy: %d\n"
			+ "Base: %d | Esclavos: %d | Gladiadores: %d | Bestias: %d\n"
			+ "Ingresos históricos: %d | Gastos históricos: %d\n[color=orange]%s[/color]"
		)
		% [
			int(data.get("monthly_operating_costs", data.get("monthly_fixed_costs", 0))),
			int(data.get("total_debt", 0)),
			int(breakdown.get("fixed_expense", 0)),
			int(breakdown.get("slave_cost", 0)),
			int(breakdown.get("gladiator_cost", 0)),
			int(breakdown.get("beast_cost", 0)),
			int(data.get("total_income", 0)),
			int(data.get("total_expenses", 0)),
			data.get("message", ""),
		]
	)
	_refresh_contracts()
	_refresh_loans()
	_refresh_ledger()
	sponsor_selector.disabled = true
	loan_selector.disabled = true
	sign_button.disabled = true
	loan_button.disabled = true
	sign_button.tooltip_text = str(data.get("sponsor_unavailable_reason", "Fuera de la demo."))
	loan_button.tooltip_text = str(data.get("loan_unavailable_reason", "Fuera de la demo."))
	status.text = "Economía mensual activa · sponsors y préstamos fuera del alcance funcional de la demo."


func _refresh_contracts() -> void:
	if EconomyManager.active_contracts.is_empty():
		contracts.text = "[b]CONTRATOS LEGACY[/b]\nNinguno · no se pueden crear nuevos en la demo."
		return
	var lines: Array[String] = ["[b]CONTRATOS LEGACY · SOLO COMPATIBILIDAD SAVE v14[/b]"]
	for contract in EconomyManager.active_contracts:
		lines.append("• %s · sin efecto económico mensual" % contract.get("name", "Contrato"))
	contracts.text = "\n".join(lines)


func _refresh_loans() -> void:
	if EconomyManager.active_loans.is_empty():
		loans.text = "[b]DEUDAS LEGACY[/b]\nNinguna · no se pueden crear nuevas en la demo."
		return
	var lines: Array[String] = ["[b]DEUDAS LEGACY · SOLO COMPATIBILIDAD SAVE v14[/b]"]
	for loan in EconomyManager.active_loans:
		lines.append(
			(
				"• %s · saldo legacy %d · sin cuota mensual activa"
				% [loan.get("name", "Préstamo"), int(loan.get("remaining", 0))]
			)
		)
	loans.text = "\n".join(lines)


func _refresh_ledger() -> void:
	var lines: Array[String] = ["[b]ÚLTIMOS MOVIMIENTOS[/b]"]
	for index in range(mini(12, EconomyManager.ledger.size())):
		var entry: Dictionary = EconomyManager.ledger[index]
		var amount := int(entry.get("amount", 0))
		(
			lines
			. append(
				(
					"Mes %d | %s%d | %s"
					% [
						int(entry.get("month", entry.get("week", entry.get("day", 0)))),
						"+" if amount >= 0 else "",
						amount,
						entry.get("reason", "Movimiento"),
					]
				)
			)
		)
	ledger.text = "\n".join(lines)


func _scroll_to_ledger() -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
