// Contract Logic:
// 1. An account creates a new list.
// 2. An account creates a new task on their list.
// 3. Whenever someone creates a new task, emit a event.task_created
// 4. Let an account mark their task as completed.

module todolist_addr::todolist {
    use std::signer;
    use aptos_framework::event;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account;
    #[test_only]  // Alias only used in test must be positioned under #[test_only]
    use std::string;

    // Errors
    const E_NOT_INITIALIZED: u64 = 1;
    const ETASK_DOESNT_EXIST: u64 = 2;
    const ETASK_IS_COMPLETED: u64 = 3;

    // Key ability allows struct to be used as a storage identifier.
    struct TodoList has key {
        tasks: Table<u64, Task>,  // tasks array
        set_task_event: event::EventHandle<Task>,  // new task event
        task_counter: u64  // a task counter that counts the number of created tasks (we can use that to differentiate between the tasks)
    }

    // A struct that has the , and abilities.storedropcopy
    // - Task needs as it's stored inside another struct (TodoList)StoreStore
    // - value can be copied (or cloned by value).Copy
    // - value can be dropped by the end of scope.Drop
    struct Task has store, drop, copy {
        task_id: u64,  // the task ID - derived from the TodoList task counter.
        address:address,  // address - the account address who created that task.
        content: String,  // content - the task content.
        completed: bool,  // completed - a boolean that marks whether that task is completed or not.
    }

    // Creating a list is essentially submitting a transaction, and so we need to know the who signed and submitted the transaction:signer
    public entry fun create_list(account: &signer){
        // entry - an entry function is a function that can be called via transactions. Simply put, whenever you want to submit a transaction to the chain, you should call an entry function.
        // signer - The signer argument is injected by the Move VM as the address who signed that transaction.
        let tasks_holder = TodoList {
            tasks: table::new(),
            set_task_event: account::new_event_handle<Task>(account),
            task_counter: 0
        };
        // move the TodoList resource under the signer account
        move_to(account, tasks_holder);

    }

    public entry fun create_task(account: &signer, content: String) acquires TodoList {
        // gets the signer address, so we can get this account's resource.
        let signer_address = signer::address_of(account);
        // assert signer has created a list
        assert!(exists<TodoList>(signer_address), E_NOT_INITIALIZED);
        // gets the TodoList resource
        let todo_list = borrow_global_mut<TodoList>(signer_address);
        // increment task counter
        let counter = todo_list.task_counter + 1;
        // creates a new Task
        let new_task = Task {
            task_id: counter,
            address: signer_address,
            content,
            completed: false
        };
        // adds the new task into the tasks table
        table::upsert(&mut todo_list.tasks, counter, new_task);
        // sets the task counter to be the incremented counter
        todo_list.task_counter = counter;
        // fires a new task created event
        event::emit_event<Task>(
            &mut borrow_global_mut<TodoList>(signer_address).set_task_event,
            new_task,
        );
    }

    // mark a task as completed.
    public entry fun complete_task(account: &signer, task_id: u64) acquires TodoList {
        // gets the signer address
        let signer_address = signer::address_of(account);
        // assert signer has created a list
        assert!(exists<TodoList>(signer_address), E_NOT_INITIALIZED);
        // gets the TodoList resource
        let todo_list = borrow_global_mut<TodoList>(signer_address);
        // assert task exists
        assert!(table::contains(&todo_list.tasks, task_id), ETASK_DOESNT_EXIST);
        // gets the task matched the task_id
        let task_record = table::borrow_mut(&mut todo_list.tasks, task_id);
        // assert task is not completed
        assert!(task_record.completed == false, ETASK_IS_COMPLETED);
        // update task as completed
        task_record.completed = true;
    }

    #[test(admin = @0x123)]  // Since our tests run outside an account scope, we need to create accounts to use in our tests. The annotation gives us the option to declare those accounts.
    // create a list
    // create a task
    // update task as completed
    public entry fun test_flow(admin: signer) acquires TodoList {
        // creates an admin @todolist_addr account for test
        account::create_account_for_test(signer::address_of(&admin));
        // initialize contract with admin account
        create_list(&admin);

        // creates a task by the admin account
        create_task(&admin, string::utf8(b"New Task"));
        let task_count = event::counter(&borrow_global<TodoList>(signer::address_of(&admin)).set_task_event);
        assert!(task_count == 1, 4);
        let todo_list = borrow_global<TodoList>(signer::address_of(&admin));
        assert!(todo_list.task_counter == 1, 5);
        let task_record = table::borrow(&todo_list.tasks, todo_list.task_counter);
        assert!(task_record.task_id == 1, 6);
        assert!(task_record.completed == false, 7);
        assert!(task_record.content == string::utf8(b"New Task"), 8);
        assert!(task_record.address == signer::address_of(&admin), 9);

        // updates task as completed
        complete_task(&admin, 1);
        let todo_list = borrow_global<TodoList>(signer::address_of(&admin));
        let task_record = table::borrow(&todo_list.tasks, 1);
        assert!(task_record.task_id == 1, 10);
        assert!(task_record.completed == true, 11);
        assert!(task_record.content == string::utf8(b"New Task"), 12);
        assert!(task_record.address == signer::address_of(&admin), 13);
    }

    #[test(admin = @0x123)]
    // This test confirms that an account can't use that function if they haven't created a list before.
    #[expected_failure(abort_code = E_NOT_INITIALIZED)]
    // The test also uses a special annotation #[expected_failure] that, as the name suggests, expects to fail with an E_NOT_INITIALIZED error code.
    public entry fun account_can_not_update_task(admin: signer) acquires TodoList {
        // creates an admin @todolist_addr account for test
        account::create_account_for_test(signer::address_of(&admin));
        // account can not toggle task as no list was created
        complete_task(&admin, 2);
    }
}

