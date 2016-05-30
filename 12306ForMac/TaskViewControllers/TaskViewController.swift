//
//  TaskViewController.swift
//  12306ForMac
//
//  Created by fancymax on 16/3/13.
//  Copyright © 2016年 fancy. All rights reserved.
//

import Cocoa
import RealmSwift

class TaskViewController: NSViewController{
    var stationDataService = StationData()

    @IBOutlet var contextMenu: NSMenu!
    @IBOutlet weak var fromStationName: AutoCompleteTextField!
    @IBOutlet weak var toStationName: AutoCompleteTextField!
    @IBOutlet weak var queryDate: NSDatePicker!
    var calendarPopover:NSPopover?
    
    @IBOutlet weak var passengerStackView: NSStackView!
    @IBOutlet weak var seatTypeStackView: NSStackView!
    @IBOutlet weak var trainCodeStackView: NSStackView!
    
    @IBOutlet weak var taskListTable: NSTableView!
    var tasks = [TicketTask]()
    var currentTask: TicketTask = TicketTask()
    var currentPassengers = [PassengerDTO]()
    var currentSeatTypes = [SeatTypeModel]()
    var currentTrainCodes = [QueryLeftNewDTO]()
    
    var ticketSelectWindowController: TicketSelectWindowController!
    var trainCodeViewControllerList = [TrainCodeViewController]()
    
    var passengerViewControllerList = [PassengerViewController]()
    let passengerSelectViewController = PassengerSelectViewController()
    lazy var passengerPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .Semitransient
        popover.contentViewController = self.passengerSelectViewController
        return popover
        }()
    
    var seatTypeViewControllerList = [SeatTypeViewController]()
    let seatTypeSelectViewController = SeatTypeSelectViewController()
    lazy var seatTypePopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .Semitransient
        popover.contentViewController = self.seatTypeSelectViewController
        return popover
        }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.fromStationName.tableViewDelegate = self
        self.toStationName.tableViewDelegate = self
        
        let realm = try! Realm()
        let task = realm.objects(TicketTask)
        for i in 0 ..< task.count {
            self.tasks.append(task[i])
        }
        
        if tasks.count > 0 {
            let index = 0
            taskListTable.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
        }
        
        self.queryDate.dateValue = NSDate()
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(TaskViewController.receiveDidSendCheckPassengerMessageNotification(_:)), name: DidSendCheckPassengerMessageNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(TaskViewController.receiveDidSendCheckSeatTypeMessageNotification(_:)), name: DidSendCheckSeatTypeMessageNotification, object: nil)
    }
    
    deinit{
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self)
    }
    
// MARK:Add TrainCode
    @IBAction func addTrainCode(sender: LoginButton) {
        ticketSelectWindowController = TicketSelectWindowController()
        ticketSelectWindowController.lastTickets = self.currentTrainCodes
        ticketSelectWindowController.fromStationCode = stationDataService.allStationMap[fromStationName.stringValue]?.Code
        ticketSelectWindowController.toStationCode = stationDataService.allStationMap[toStationName.stringValue]?.Code
        
        let dateStr = queryDate.dateValue.description
        let dateRange = dateStr.rangeOfString(" ")
        ticketSelectWindowController.date = dateStr[dateStr.startIndex..<dateRange!.startIndex]
        
        if let window = self.view.window {
            window.beginSheet(ticketSelectWindowController.window!) {
                if $0 == NSModalResponseOK{
                    self.currentTrainCodes = self.ticketSelectWindowController.ticketQueryResult
                    self.addSelectedTrainToStackView()
                }
            }
        }
    }
    
    func addSelectedTrainToStackView() {
        for i in 0..<currentTrainCodes.count {
            if currentTrainCodes[i].isSelected {
                if !hasTrainCode(currentTrainCodes[i]) {
                    let p = TrainCodeViewController()
                    p.delegate = self
                    p.ticket = currentTrainCodes[i]
                    self.trainCodeStackView.addView(p.view, inGravity: .Top)
                    self.trainCodeViewControllerList.append(p)
                }
                else{
                    selectTicketCode(currentTrainCodes[i])
                }
            }
            else{
                unSelectTicketCode(currentTrainCodes[i]);
            }
        }
    }
    
    func selectTicketCode(ticket:QueryLeftNewDTO){
        for controller in trainCodeViewControllerList where controller.ticket.TrainCode == ticket.TrainCode{
            controller.select()
        }
    }
    
    func unSelectTicketCode(ticket:QueryLeftNewDTO){
        for controller in trainCodeViewControllerList where controller.ticket.TrainCode == ticket.TrainCode{
            controller.unSelect()
        }
    }
    
    func unSelectCurrentTrainCode(ticket:QueryLeftNewDTO) {
        for currentTicket in currentTrainCodes where currentTicket.TrainCode == ticket.TrainCode{
            currentTicket.isSelected = false;
        }
    }
    
    func hasTrainCode(ticket: QueryLeftNewDTO) -> Bool {
        for controller in trainCodeViewControllerList{
            if controller.ticket.TrainCode == ticket.TrainCode {
                return true
            }
        }
        
        return false
    }
    
// MARK:Add Passenger
    @IBAction func addPassenger(sender: LoginButton) {
        if currentPassengers.count == 0{
            for p in MainModel.passengers {
                let passenger = PassengerDTO()
                passenger.passenger_id_no = p.passenger_id_no
                passenger.passenger_name = p.passenger_name
                currentPassengers.append(passenger)
            }
        }
        
        let positioningView = sender
        let positioningRect = NSZeroRect
        let preferredEdge = NSRectEdge.MaxY
        
        passengerPopover.showRelativeToRect(positioningRect, ofView: positioningView, preferredEdge: preferredEdge)
        
        passengerSelectViewController.reloadPassenger(currentPassengers)
    }
    
    func receiveDidSendCheckPassengerMessageNotification(notification: NSNotification) {
        if !self.passengerPopover.shown {
            print("not receiveDidSendCheckPassengerMessageNotification in TaskViewController")
            return
        }
        
        let name = notification.object as! String
        
        for i in 0..<currentPassengers.count {
            if currentPassengers[i].passenger_name == name{
                if passengerSelected(currentPassengers[i]){
                    checkPassenger(currentPassengers[i])
                }
                else{
                    let p = PassengerViewController()
                    p.passenger = currentPassengers[i]
                    passengerViewControllerList.append(p)
                    self.passengerStackView.addView(p.view, inGravity:.Top)
                }
                
                break
            }
        }
    }
    
    func passengerSelected(passenger:PassengerDTO) -> Bool{
        for controller in passengerViewControllerList where controller.passenger == passenger{
            return true
        }
        return false
    }
    
    func checkPassenger(passenger:PassengerDTO){
        for controller in passengerViewControllerList where controller.passenger == passenger{
            controller.select()
        }
    }
    
// MARK:Add TicketType
    @IBAction func addTicketType(sender: LoginButton) {
        if currentSeatTypes.count == 0{
            for p in MainModel.seatTypes {
                let ticketType = SeatTypeModel()
                ticketType.name = p
                ticketType.id = MainModel.ticketTypeNameDic[p]
                currentSeatTypes.append(ticketType)
            }
        }
        
        let positioningView = sender
        let positioningRect = NSZeroRect
        let preferredEdge = NSRectEdge.MaxY
        
        seatTypePopover.showRelativeToRect(positioningRect, ofView: positioningView, preferredEdge: preferredEdge)
        
        seatTypeSelectViewController.reloadTicketTypes(currentSeatTypes)
    }
    
    func receiveDidSendCheckSeatTypeMessageNotification(notification: NSNotification){
        if !self.seatTypePopover.shown {
            print("not receiveDidSendCheckSeatTypeMessageNotification in TaskViewController")
            return
        }
        let name = notification.object as! String
        
        for i in 0..<currentSeatTypes.count {
            if currentSeatTypes[i].name == name{
                if seatSelected(currentSeatTypes[i]){
                    checkSeat(currentSeatTypes[i])
                }
                else{
                    let p = SeatTypeViewController()
                    p.seatType = currentSeatTypes[i]
                    seatTypeViewControllerList.append(p)
                    self.seatTypeStackView.addView(p.view, inGravity:.Top)
                }
                
                break
            }
        }
    }
    
    func seatSelected(seatType:SeatTypeModel) -> Bool{
        for controller in seatTypeViewControllerList where controller.seatType == seatType{
            return true
        }
        return false
    }
    
    func checkSeat(seatType:SeatTypeModel){
        for controller in seatTypeViewControllerList where controller.seatType == seatType{
            controller.select()
        }
    }
    
// MARK:Handle Task
    @IBAction func addTask(sender: NSButton) {
        let task = TicketTask()
        task.id = self.taskListTable.numberOfRows
        tasks.append(task)
        
        let index = taskListTable.numberOfRows
        self.taskListTable.reloadData()
        taskListTable.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
        loadTask(task)
        taskListTable.scrollRowToVisible(index)
    }
    
    @IBAction func deleteTask(sender: NSMenuItem) {
        if self.taskListTable.clickedRow != -1 {
            let realm = try! Realm()
            try! realm.write {
                realm.delete(self.tasks[self.taskListTable.clickedRow])
            }
            self.tasks.removeAtIndex(self.taskListTable.clickedRow)
        }
        self.taskListTable.reloadData()
    }
    
    @IBAction func saveTask(sender: NSButton) {
        
        
        let realm = try! Realm()
        try! realm.write {
            currentTask = realm.create(TicketTask.self, value: ["id": currentTask.id,
                "fromStationName": self.fromStationName.stringValue,
                "toStationName": self.toStationName.stringValue,
                "date": self.queryDate.dateValue],
                update: true)
        }
        self.tasks[self.taskListTable.selectedRow] = currentTask
        let row = self.taskListTable.selectedRow
        self.taskListTable.reloadDataForRowIndexes(NSIndexSet(index: row), columnIndexes: NSIndexSet(index: 0))
    }
}

// MARK: - NSTableViewDataSource,NSTableViewDelegate
extension TaskViewController:NSTableViewDataSource,NSTableViewDelegate{
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return tasks.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        return tasks[row]
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        
        let task = self.tasks[self.taskListTable.selectedRow]
        loadTask(task)
    }
    
    func loadTask(task:TicketTask){
        self.currentTask = task
        self.fromStationName.stringValue = task.fromStationName
        self.toStationName.stringValue = task.toStationName
        self.queryDate.dateValue = task.date
    }
}

// MARK: - AutoCompleteTableViewDelegate
extension TaskViewController: AutoCompleteTableViewDelegate{
    func textField(textField: NSTextField, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: Int) -> [String] {
        var matches = [String]()
        //先按简拼  再按全拼  并保留上一次的match
        for station in stationDataService.allStation
        {
            if let _ = station.FirstLetter.rangeOfString(textField.stringValue, options: NSStringCompareOptions.AnchoredSearch)
            {
                matches.append(station.Name)
            }
        }
        
        if(matches.isEmpty)
        {
            for station in stationDataService.allStation
            {
                if let _ = station.Spell.rangeOfString(textField.stringValue, options: NSStringCompareOptions.AnchoredSearch)
                {
                    matches.append(station.Name)
                }
            }
        }
        //再按汉字
        if(matches.isEmpty)
        {
            for station in stationDataService.allStation
            {
                if let _ = station.Name.rangeOfString(textField.stringValue, options: NSStringCompareOptions.AnchoredSearch)
                {
                    matches.append(station.Name)
                }
            }
        }
        
        return matches
    }
}

// MARK: - LunarCalendarViewDelegate
extension TaskViewController: LunarCalendarViewDelegate{
    func createCalenderPopover(){
        var myPopover = self.calendarPopover
        if(myPopover == nil){
            myPopover = NSPopover()
            let cp = LunarCalendarView()
            cp.delegate = self
            cp.date = self.queryDate.dateValue
            cp.selectedDate = self.queryDate.dateValue
            myPopover!.contentViewController = cp
            myPopover!.appearance = NSAppearance(named: "NSAppearanceNameAqua")
            myPopover!.animates = true
            myPopover!.behavior = NSPopoverBehavior.Transient
        }
        self.calendarPopover = myPopover
    }
    
    @IBAction func showCalendar(sender: AnyObject){
        self.createCalenderPopover()
        let cellRect = sender.bounds
        self.calendarPopover?.showRelativeToRect(cellRect, ofView: sender as! NSView, preferredEdge: .MaxY)
    }
    
    func didSelectDate(selectedDate: NSDate) {
        self.queryDate!.dateValue = selectedDate
        self.calendarPopover?.close()
    }
}