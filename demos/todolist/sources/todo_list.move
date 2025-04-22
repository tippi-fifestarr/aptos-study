module todo_list_add::todo_list {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::event;
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
    }
}
