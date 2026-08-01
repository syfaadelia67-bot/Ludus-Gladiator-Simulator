extends VBoxContainer

@onready var summary: RichTextLabel = $Summary
@onready var sponsor_selector: OptionButton = $ContractRow/SponsorSelector
@onready var sign_button: Button = $ContractRow/SignContract
@onready var loan_selector: OptionButton = $LoanRow/LoanSelector
@onready var loan_button: Button = $LoanRow/TakeLoan
@onready var contracts: RichTextLabel = $Columns/Contracts
@onready var loans: RichTextLabel = $Columns/Loans
@onready var ledger: RichTextLabel = $Ledger
@onready var status: Label = $Status

var sponsor_ids: Array[String] = []
var loan_ids: Array[String] = []

func _ready() -> void:
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

func _populate_options() -> void:
    sponsor_selector.clear()
    sponsor_ids = EconomyManager.get_sponsor_ids()
    for sponsor_id in sponsor_ids:
        var data := EconomyManager.get_sponsor(sponsor_id)
        sponsor_selector.add_item("%s — Rep. %d" % [data.get("name", sponsor_id), int(data.get("required_reputation", 0))])
    loan_selector.clear()
    loan_ids = EconomyManager.get_loan_ids()
    for loan_id in loan_ids:
        var data := EconomyManager.get_loan_product(loan_id)
        loan_selector.add_item("%s — %d denarios" % [data.get("name", loan_id), int(data.get("principal", 0))])

func _on_sign_contract() -> void:
    if sponsor_selector.selected < 0 or sponsor_ids.is_empty():
        _show_error("Seleccioná un patrocinador.")
        return
    if EconomyManager.sign_contract(sponsor_ids[sponsor_selector.selected]):
        status.text = "Contrato firmado correctamente."

func _on_take_loan() -> void:
    if loan_selector.selected < 0 or loan_ids.is_empty():
        _show_error("Seleccioná un préstamo.")
        return
    if EconomyManager.take_loan(loan_ids[loan_selector.selected]):
        status.text = "El préstamo fue depositado en la tesorería."

func _on_selection_changed(_index: int) -> void:
    _refresh()

func _on_bankruptcy_warning(_level: int, message: String) -> void:
    status.text = message

func _show_error(reason: String) -> void:
    status.text = reason

func _refresh() -> void:
    var data := EconomyManager.get_summary()
    summary.text = "[b]TESORERÍA[/b]\nCosto fijo semanal: %d | Deuda: %d | Contratos: %d | Préstamos: %d\nIngresos históricos: %d | Gastos históricos: %d\n[color=orange]%s[/color]" % [int(data.get("weekly_fixed_costs", data.get("daily_fixed_costs", 0))), int(data.get("total_debt", 0)), int(data.get("contracts", 0)), int(data.get("loans", 0)), int(data.get("total_income", 0)), int(data.get("total_expenses", 0)), data.get("message", "")]
    _refresh_contracts()
    _refresh_loans()
    _refresh_ledger()
    if sponsor_selector.selected >= 0 and sponsor_selector.selected < sponsor_ids.size():
        var sponsor := EconomyManager.get_sponsor(sponsor_ids[sponsor_selector.selected])
        sign_button.disabled = not bool(sponsor.get("eligible", false))
        sign_button.tooltip_text = "Anticipo %d | Ingreso semanal %d | Duración %d semanas" % [int(sponsor.get("upfront", 0)), int(sponsor.get("daily_income", 0)), int(sponsor.get("duration", 0))]

func _refresh_contracts() -> void:
    if EconomyManager.active_contracts.is_empty():
        contracts.text = "[b]CONTRATOS ACTIVOS[/b]\nNinguno"
        return
    var lines: Array[String] = ["[b]CONTRATOS ACTIVOS[/b]"]
    for contract in EconomyManager.active_contracts:
        lines.append("• %s — %d semanas — +%d/semana — V:%d D:%d" % [contract.get("name", "Contrato"), int(contract.get("days_remaining", 0)), int(contract.get("daily_income", 0)), int(contract.get("victories", 0)), int(contract.get("defeats", 0))])
    contracts.text = "\n".join(lines)

func _refresh_loans() -> void:
    if EconomyManager.active_loans.is_empty():
        loans.text = "[b]DEUDAS ACTIVAS[/b]\nNinguna"
        return
    var lines: Array[String] = ["[b]DEUDAS ACTIVAS[/b]"]
    for loan in EconomyManager.active_loans:
        lines.append("• %s — Debe %d — Cuota semanal %d — Impagos %d" % [loan.get("name", "Préstamo"), int(loan.get("remaining", 0)), int(loan.get("installment", 0)), int(loan.get("missed", 0))])
    loans.text = "\n".join(lines)

func _refresh_ledger() -> void:
    var lines: Array[String] = ["[b]ÚLTIMOS MOVIMIENTOS[/b]"]
    for index in range(mini(12, EconomyManager.ledger.size())):
        var entry: Dictionary = EconomyManager.ledger[index]
        var amount := int(entry.get("amount", 0))
        lines.append("Semana %d | %s%d | %s" % [int(entry.get("day", 0)), "+" if amount >= 0 else "", amount, entry.get("reason", "Movimiento")])
    ledger.text = "\n".join(lines)
