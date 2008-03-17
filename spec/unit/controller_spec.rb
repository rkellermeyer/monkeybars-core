require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'monkeybars/view'
require 'monkeybars/controller'
require 'spec/unit/test_files.jar'
include_class 'java.awt.event.ActionEvent'
include_class 'java.awt.event.MouseEvent'
include_class 'java.awt.event.WindowEvent'


class TestView < Monkeybars::View
  set_java_class 'org.monkeybars.TestView'
end

describe Monkeybars::Controller do
  
  it "allows the model and view to be set externally" do
    class TestController < Monkeybars::Controller; end
    class MyTestView; end
    class MyTestModel; end
    
    TestController.set_view "MyTestView"
    TestController.set_model "MyTestModel"
    
    TestController.send(:view_class).should == "MyTestView"
    TestController.send(:model_class).should == "MyTestModel"
  end
  
  it "allows the model and view to be overriden externally" do
    class MyTestView; end
    class MyTestModel; end
    class MyTestView2; end
    class MyTestModel2; end
    
    class TestController < Monkeybars::Controller
      set_view "MyTestView"
      set_model "MyTestModel"
    end
    
    TestController.set_view "MyTestView2"
    TestController.set_model "MyTestModel2"
    
    TestController.send(:view_class).should == "MyTestView2"
    TestController.send(:model_class).should == "MyTestModel2"
  end
end

describe "Controller instantiation" do
  before(:each) do
    Object.send(:remove_const, :TestController) if Object.const_defined? :TestController
  end
  
  it "will not create more than once instance" do
    class TestController < Monkeybars::Controller; end
    
    t = TestController.instance
    t2 = TestController.instance
    t.should equal(t2)
  end
end

describe Monkeybars::Controller, ' nesting' do
  it "invokes controller group's nesting#add on add_nested_controller" do
    controller = TestController.instance
    controller.stub! :model
    controller.stub! :transfer
    view = mock("view")
    view.should_receive :add_nested_view
    controller.instance_variable_set(:@__view, view)
    
    foo_component = mock("foo_component")
    
    foo_view = mock("foo_view")
    foo_view.instance_variable_set(:@main_view_component, foo_component)
    
    foo_controller = mock("foo_controller")
    foo_controller.instance_variable_set(:@__view, foo_view)
    
    controller.add_nested_controller :foo, foo_controller
  end
  
  it "invokes controller group's nesting#remove on remove_nested_controller" do
    controller = TestController.instance
    controller.stub! :model
    controller.stub! :transfer
    view = mock("view")
    view.should_receive :remove_nested_view
    controller.instance_variable_set(:@__view, view)
    
    foo_component = mock("foo_component")
    
    foo_view = mock("foo_view")
    foo_view.instance_variable_set(:@main_view_component, foo_component)
    
    foo_controller = mock("foo_controller")
    foo_controller.instance_variable_set(:@__view, foo_view)
    
    controller.remove_nested_controller :foo, foo_controller
  end
end

describe Monkeybars::Controller, "#handle_event" do
  before(:each) do
    
    class HandleEventController < Monkeybars::Controller
      set_view "TestView"
      add_listener :type => :action, :components => ["testButton"]
      add_listener :type => :document, :components => ["testTextField.document"]
      
      def test_button_action_performed(event)
        $test_button_action_performed = true
      end
    end
  end
  
  it "should try to call the most specific handler available first" do
    $test_button_action_performed = false
    t = HandleEventController.instance
    target_component = t.instance_variable_get("@__view").get_field_value("testButton")
    event = ActionEvent.new(target_component, ActionEvent::ACTION_PERFORMED, "")
    t.handle_event("test_button", 'action_performed', event)
    $test_button_action_performed.should == true
    
    t.close
  end
  
  it "should call a global event handler if no specific component handler is defined"
end

describe Monkeybars::Controller, "#add_handler_for" do
  
  it "does not overwrite the controller's method_missing method" do
    class AddHandlerForController < Monkeybars::Controller
      set_view "TestView"
      
      add_listener :type => :action, :components => ["testButton"]
      
      def method_missing(method, *args, &block)
	return "original method missing"
      end
    end
    
    t = AddHandlerForController.instance
    t.foobar.should == "original method missing"
    t.close
  end
end

describe Monkeybars::Controller, "#view_state" do
  
  it "returns the view's state as a model and a transfer hash" do  
    class ViewStateModel
      attr_accessor :text
      def initialize; @text= ""; end
    end
    
    class ViewStateView < Monkeybars::View
      set_java_class "org.monkeybars.TestView"
      map :view => "testTextField.text", :model => :text
      map :view => "testTextField.columns", :transfer => :text_columns
      
      def load
	testTextField.columns = 10
      end
    end
    
    class ViewStateController < Monkeybars::Controller
      set_view "ViewStateView"
      set_model "ViewStateModel"
    end
    
    t = ViewStateController.instance
    
    view_state, transfer = t.send(:view_state)
    view_state.text.should == "A text field"
    transfer[:text_columns].should == 10
    t.instance_variable_get("@__view").testTextField.text = "test data"
    t.instance_variable_get("@__view").testTextField.columns = 20
    view_state, transfer = t.send(:view_state)
    view_state.text.should == "test data"
    transfer[:text_columns].should == 20
    
    t.close
  end
end

describe Monkeybars::Controller, "#update_model" do
  
  it "updates the declared properties of the model from the view_state" do
    class UpdateModelModel; attr_accessor :text, :text2, :text3; end
    class UpdateModelController < Monkeybars::Controller; set_model "UpdateModelModel"; end
    
    t = UpdateModelController.instance
    m = UpdateModelModel.new
    m.text = "some test data"
    m.text2 = "some test data"
    m.text3 = "some test data"
    
    t.send(:model).text = ""
    t.send(:model).text2 = ""
    t.send(:model).text2 = ""
    t.send(:update_model, m, :text, :text3)
    t.send(:model).text.should == "some test data"
    t.send(:model).text2.should == ""
    t.send(:model).text3.should == "some test data"
    t.close
  end
end

describe Monkeybars::Controller, "implicit handler registration" do
  
  it "detects event names in methods and adds an appropriate listener during instantiation" do
    class ImplicitRegisterView < Monkeybars::View
      set_java_class "org.monkeybars.TestView"
      
      def add_handler(handler, component)
        handler.type.should == "Action"
	handler.instance_variable_get("@component_name").should == "test_button"
        component.should == "test_button"
        $add_handler_called = true
      end
    end
    
    class ImplicitRegisterController < Monkeybars::Controller
      set_view "ImplicitRegisterView"
      
      def test_button_action_performed
	
      end
    end
    
    t = ImplicitRegisterController.instance
    $add_handler_called.should be_true
    t.close
  end

  it "does not add an implicit handler if an explict handler of that type was already added for that component"
  it "detects the type of the listener to use for the component when using an implicit handler"
  it "detects when a new method is added and registers a new listener if appropriate"
end

describe Monkeybars::Controller, "#signal" do
  
  it "invokes the view's process_signal method, passing along a block if given" do
    class SignalView < Monkeybars::View
      def process_signal(signal_name, model, transfer, &callback)
	raise "No block given!" unless block_given?
        raise "Incorrect signal name!" unless :signal1 == signal_name
      end
    end
    class SignalController < Monkeybars::Controller
      set_view 'SignalView'
    end
    
    controller = SignalController.instance
    lambda {controller.signal(:signal1) {"dummy block"}}.should_not raise_error(Exception)
  end
end

describe Monkeybars::Controller, "closing the controller" do
  
  module Monkeybars
    class Controller
      def self.cleanup_instances
        class_variable_get(:@@instance_list).clear
      end
    end
  end
  
  before(:each) { Monkeybars::Controller::cleanup_instances }
  
  class ClosingTestView < Monkeybars::View
    set_java_class 'org.monkeybars.TestView'
    def close
      java_window.process_window_event WindowEvent.new(java_window, WindowEvent::WINDOW_CLOSING)
    end
  end

  class ClosingController < Monkeybars::Controller
    set_view 'ClosingTestView'
  end
  
  class AnotherClosingController < Monkeybars::Controller
    set_view 'ClosingTestView'
  end
  

  def close_controller_test_case(close_action = nil)
    ClosingController.set_close_action(close_action) unless close_action.nil?
    controller = ClosingController.instance
    view = controller.instance_variable_get("@__view")
    yield controller, view
    view.close
  end
  
  it "should trigger unload if no close action is specified" do
    close_controller_test_case do |controller, view| # default
      controller.should_receive :unload
      view.should_receive :unload
      view.should_receive :dispose
    end
  end
  
  it "should should trigger unload if :close action is specified" do
    close_controller_test_case :close do |controller, view|
      controller.should_receive :unload
      view.should_receive :unload
      view.should_receive :dispose
    end
  end
  
  it "should should trigger unload on all controllers if :exit action is specified and the system should exit" do
    close_controller_test_case :exit do |controller, view|
      expectations = lambda {|c, v|
        c.should_receive :unload
        v.should_receive :unload
        v.should_receive :dispose
      }
      expectations.call(controller, view)
      
      another_controller = AnotherClosingController.instance
      another_view = another_controller.instance_variable_get("@__view")
      expectations.call(another_controller, another_view)

      java.lang.System.should_receive :exit
    end
  end
  
  it "should not trigger unload when the controller is configured with :nothing action" do
    close_controller_test_case :nothing do |controller, view|
      controller.should_not_receive :unload
      view.should_not_receive :unload
    end
  end

  it "should not trigger unload when the controller is configured with :dispose action but the view should be disposed" do
    close_controller_test_case(:dispose) do |controller, view|
      controller.should_not_receive :unload
      view.should_receive :dispose
    end
  end

  it "should not trigger unload when the controller is configured with :hide action but the view should be hidden" do
    close_controller_test_case(:hide) do |controller, view|
      controller.should_not_receive :unload
      view.should_receive :hide
    end
  end
end

