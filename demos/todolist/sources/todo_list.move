module todo_list_add::todo_list {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::event;
    use aptos_std::string_utils;
    use std::bcs;
    use aptos_framework::object;
    use std::vector;

    #[test_only]
    use std::debug;


      //:!:>errors

        /// Todo list does not exist
    const E_TODO_LIST_DOSE_NOT_EXIST: u64 = 1;
    /// Todo does not exist
    const E_TODO_DOSE_NOT_EXIST: u64 = 2;
    /// Todo is already completed
    const E_TODO_ALREADY_COMPLETED: u64 = 3;
      //:!:>errors

    

    //:!:>resource

#[resource_group_member(group = aptos_framework::object::ObjectGroup)] // This grouping is a gas-optimization technique: it keeps related data in the same storage slot. 
struct UserTodoListCounter has key {
    counter : u64,
}
#[resource_group_member(group = aptos_framework::object::ObjectGroup)]
struct TodoList has key {
    owner : address,
    todos : vector<Todo>,
}
#[resource_group_member(group = aptos_framework::object::ObjectGroup)]
struct Todo has key, store, copy {
    content : string::String,
    is_completed: bool,
}
    //<:!:resource
    //<:!: constructor like :D 


    fun init_module(singer: &signer){
        // should init contract here ,
        // @notice , is optional,
        // @notice , only signer is expected as param here 
    }



    public entry fun create_user_todo_list(user:&signer) acquires UserTodoListCounter{
        // check if user has one , if yes increase the counter 
        let user_address = signer::address_of(user);
        let counter = if ( exists<UserTodoListCounter>(user_address)){
            let counter = borrow_global<UserTodoListCounter>(user_address);
            counter.counter
        }else {
            move_to(user,UserTodoListCounter{counter:0});
                0            
        };
        // create address that will hold the todo list 
        // This type is not deletable and has a deterministic address. You can create it by using: 0x1::object::create_named_object(creator: &signer, seed: vector<u8>). ref : https://aptos.dev/en/build/smart-contracts/object/creating-objects
        let obj_hold_add = object::create_named_object(
            // singer , seed 
            user, construct_todo_list_object_seed(counter)
        );
        let obj_add = object::generate_signer(&obj_hold_add);
        let todo = TodoList{
            owner: user_address,
            todos: vector::empty(),
        };
        move_to(&obj_add,todo);
        let counter_mut = borrow_global_mut<UserTodoListCounter>(user_address);
        counter_mut.counter= counter_mut.counter+1;
    }
    public entry fun add_todo ( owner:&signer, content:string::String, todo_list_index:u64) acquires TodoList{
        let owner_add = signer::address_of(owner);
        // check if user has a todo  
    
        let obj_add = object::create_object_address(&owner_add,construct_todo_list_object_seed(todo_list_index));
        assert!(exists<TodoList>(obj_add),E_TODO_LIST_DOSE_NOT_EXIST);

        let todo_list_mut = borrow_global_mut<TodoList>(obj_add);
        let new_todo = Todo{
            content:content,
            is_completed:false,
        };
        //  you still need to explicitly use &mut to access and modify fields within it
        vector::push_back(&mut todo_list_mut.todos,  new_todo);

    }


    public entry fun finish_todo(owner :& signer, todo_list_index:u64, todo_idx: u64) acquires TodoList{
        let owner_add = signer::address_of(owner);
        let obj_add = object::create_object_address(&owner_add,construct_todo_list_object_seed(todo_list_index));
        assert!(exists<TodoList>(obj_add),E_TODO_LIST_DOSE_NOT_EXIST);
             let todo_list_mut = borrow_global_mut<TodoList>(obj_add);
     
     assert!(
            todo_idx < vector::length(&todo_list_mut.todos),
            E_TODO_DOSE_NOT_EXIST
        );
        let todo_record = vector::borrow_mut(&mut todo_list_mut.todos,todo_idx);
        assert!(todo_record.is_completed == false, E_TODO_ALREADY_COMPLETED);

        todo_record.is_completed=true;


    }
// helper functions 
       fun construct_todo_list_object_seed(counter: u64): vector<u8> {
        // The seed must be unique per todo list creator
        //Wwe add contract address as part of the seed so seed from 2 todo list contract for same user would be different
        bcs::to_bytes(&string_utils::format2(&b"{}_{}", @todo_list_add, counter))
    }


    #[test(framework = @0x1, admin = @todo_list_add, user = @0x123)]
fun test_todo_list_end_to_end(framework: &signer, admin: &signer, user: &signer) acquires TodoList, UserTodoListCounter{
    use aptos_framework::account;
    
    // Set up test environment
    account::create_account_for_test(signer::address_of(framework));
    account::create_account_for_test(signer::address_of(admin));
    account::create_account_for_test(signer::address_of(user));
    
    // Create a new todo list for the user
    create_user_todo_list(user);
    
    // Get the user address
    let user_address = signer::address_of(user);
    
    // Verify the counter was created and set to 1
    assert!(exists<UserTodoListCounter>(user_address), 0);
    let counter = borrow_global<UserTodoListCounter>(user_address);
    assert!(counter.counter == 1, 1);
    
    // Calculate the object address for the created todo list
    let todo_list_index = 0; // First todo list has index 0
    let obj_add = object::create_object_address(&user_address, construct_todo_list_object_seed(todo_list_index));
    
    // Verify the todo list exists
    assert!(exists<TodoList>(obj_add), 2);
    
    // Add two todos to the list
    let todo_content1 = string::utf8(b"Buy groceries");
    let todo_content2 = string::utf8(b"Finish Move homework");
    
    add_todo(user, todo_content1, todo_list_index);
    add_todo(user, todo_content2, todo_list_index);
    
    // Verify the todos were added
    let todo_list = borrow_global<TodoList>(obj_add);
    assert!(vector::length(&todo_list.todos) == 2, 3);
    
    // Verify todo contents - get copies of the strings for comparison
    let first_todo = vector::borrow(&todo_list.todos, 0);
    let second_todo = vector::borrow(&todo_list.todos, 1);
    
    // Convert string to bytes and then work with the actual bytes value, not reference
    let first_content_bytes = *string::bytes(&first_todo.content);
    let second_content_bytes = *string::bytes(&second_todo.content);
    
    assert!(first_content_bytes == b"Buy groceries", 4);
    assert!(second_content_bytes == b"Finish Move homework", 5);
    
    // Verify both todos are not completed
    assert!(!first_todo.is_completed, 6);
    assert!(!second_todo.is_completed, 7);
    
    // Complete the first todo
    finish_todo(user, todo_list_index, 0);
    
    // Verify the first todo is now completed
    let todo_list = borrow_global<TodoList>(obj_add);
    let first_todo = vector::borrow(&todo_list.todos, 0);
    let second_todo = vector::borrow(&todo_list.todos, 1);
    
    assert!(first_todo.is_completed, 8);
    assert!(!second_todo.is_completed, 9);
    
    // Try creating another todo list for the same user
    create_user_todo_list(user);
    
    // Verify counter was incremented
    let counter = borrow_global<UserTodoListCounter>(user_address);
    assert!(counter.counter == 2, 10);
    
    // Calculate the object address for the second todo list
    let second_todo_list_index = 1; // Second todo list has index 1
    let second_obj_add = object::create_object_address(&user_address, construct_todo_list_object_seed(second_todo_list_index));
    
    // Verify the second todo list exists
    assert!(exists<TodoList>(second_obj_add), 11);
    
    debug::print(&b"All tests passed!");
}
}
