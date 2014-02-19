require 'spec_helper'

module SimpleNavigation
  describe ItemContainer do
    let(:item_container) { ItemContainer.new }

    describe '#initialize' do
      it 'sets the renderer to the globally-configured renderer per default' do
        expect(Configuration.instance).to receive(:renderer)
        ItemContainer.new
      end

      it "sets an empty items array" do
        expect(item_container.items).to be_empty
      end
    end

    describe '#items=' do
      let(:item) { double(:item) }
      let(:items) { [item] }
      let(:item_adapter) { double(:item_adapter).as_null_object }

      before do
        ItemAdapter.stub(new: item_adapter)
        item_container.stub(should_add_item?: true)
      end

      it 'wraps each item in an ItemAdapter' do
        expect(ItemAdapter).to receive(:new)
        item_container.items = items
      end

      context 'when item should be added' do
        let(:simple_navigation_item) { double(:simple_navigation_item) }

        before do
          item_container.stub(should_add_item?: true)
          item_adapter.stub(to_simple_navigation_item: simple_navigation_item)
        end

        it 'converts the item to an Item' do
          expect(item_adapter).to receive(:to_simple_navigation_item)
                                  .with(item_container)
          item_container.items = items
        end

        it 'adds the item to the items-collection' do
          expect(item_container.items).to receive(:<<)
                                          .with(simple_navigation_item)
          item_container.items = items
        end
      end

      context 'when item should not be added' do
        before { item_container.stub(should_add_item?: false) }

        it "doesn't convert the item to an Item" do
          expect(item_adapter).not_to receive(:to_simple_navigation_item)
          item_container.items = items
        end

        it "doesn't add the item to the items-collection" do
          expect(item_container.items).not_to receive(:<<)
          item_container.items = items
        end
      end
    end

    describe '#selected?' do
      let(:item_1) { double(:item, selected?: false) }
      let(:item_2) { double(:item, selected?: false) }

      before do
        item_container.instance_variable_set(:@items, [item_1, item_2])
      end

      context 'when no item is selected' do
        it 'returns nil' do
          expect(item_container).not_to be_selected
        end
      end

      context 'when an item is selected' do
        it 'returns true' do
          item_1.stub(selected?: true)
          expect(item_container).to be_selected
        end
      end
    end

    describe '#selected_item' do
      let(:item_1) { double(:item, selected?: false) }
      let(:item_2) { double(:item, selected?: false) }

      before(:each) do
        SimpleNavigation.stub(current_navigation_for: :nav)
        item_container.stub(:[] => nil)
        item_container.instance_variable_set(:@items, [item_1, item_2])
      end

      context "when navigation isn't explicitely set" do
        context 'and no item is selected' do
          it 'returns nil' do
            expect(item_container.selected_item).to be_nil
          end
        end

        context 'and an item selected' do
          before { item_1.stub(selected?: true) }

          it 'returns the selected item' do
            expect(item_container.selected_item).to be item_1
          end
        end
      end
    end

    describe '#active_item_container_for' do
      context "when the desired level is the same as the container's" do
        it 'returns the container itself' do
          expect(item_container.active_item_container_for(1)).to be item_container
        end
      end

      context "when the desired level is different than the container's" do
        context 'and no subnavigation is selected' do
          before { item_container.stub(selected_sub_navigation?: false) }

          it 'returns nil' do
            expect(item_container.active_item_container_for(2)).to be_nil
          end
        end

        context 'and a subnavigation is selected' do
          let(:sub_navigation) { double(:sub_navigation) }
          let(:selected_item) { double(:selected_item) }

          before do
            item_container.stub(selected_sub_navigation?: true,
                                selected_item: selected_item)
            selected_item.stub(sub_navigation: sub_navigation)
          end

          it 'calls recursively on the sub_navigation' do
            expect(sub_navigation).to receive(:active_item_container_for)
                                      .with(2)
            item_container.active_item_container_for(2)
          end
        end
      end
    end

    describe '#active_leaf_container' do
      context 'when the current container has a selected subnavigation' do
        let(:sub_navigation) { double(:sub_navigation) }
        let(:selected_item) { double(:selected_item) }

        before do
          item_container.stub(selected_sub_navigation?: true,
                              selected_item: selected_item)
          selected_item.stub(sub_navigation: sub_navigation)
        end

        it 'calls recursively on the sub_navigation' do
          expect(sub_navigation).to receive(:active_leaf_container)
          item_container.active_leaf_container
        end
      end

      context 'when the current container is the leaf already' do
        before { item_container.stub(selected_sub_navigation?: false) }

        it 'returns itsself' do
          expect(item_container.active_leaf_container).to be item_container
        end
      end
    end

    describe '#item' do
      # TODO: what ?
      context 'unconditional item' do
        let(:options) { Hash.new }

        before { item_container.stub(:should_add_item?).and_return(true) }

        context 'when a block is given' do
          let(:sub_container) { double(:sub_container) }
          let(:block) { proc{} }

          before { ItemContainer.stub(:new).and_return(sub_container) }

          it 'yields a new ItemContainer' do
            expect{ |blk|
              item_container.item('key', 'name', 'url', options, &blk)
            }.to yield_with_args(sub_container)
          end

          it "creates a new Navigation-Item with the given params and block" do
            expect(Item).to receive(:new)
                            .with(item_container, 'key', 'name', 'url',
                                  options, nil, &block)
            item_container.item('key', 'name', 'url', options, &block)
          end

          it 'adds the created item to the list of items' do
            expect(item_container.items).to receive(:<<)
            item_container.item('key', 'name', 'url', options) {}
          end
        end

        context 'when no block is given' do
          it "creates a new Navigation_item with the given params and nil as sub_navigation" do
            expect(Item).to receive(:new)
                            .with(item_container, 'key', 'name', 'url', options, nil)
            item_container.item('key', 'name', 'url', options)
          end

          it 'adds the created item to the list of items' do
            expect(item_container.items).to receive(:<<)
            item_container.item('key', 'name', 'url', options)
          end
        end
      end

      describe 'Optional url and optional options' do
        shared_examples 'adding the item to the list' do
          it 'adds the item to the list' do
            expect(item_container.items).to receive(:<<)
            item_container.item(*args)
          end
        end

        shared_examples "doesn't add the item to the list" do
          it 'adds the item to the list' do
            expect(item_container.items).not_to receive(:<<)
            item_container.item(*args)
          end
        end

        context 'when item specifed without url or options' do
          it_behaves_like 'adding the item to the list' do
            let(:args) { ['key', 'name'] }
          end
        end

        context 'when item is specified with only a url' do
          it_behaves_like 'adding the item to the list' do
            let(:args) { ['key', 'name', 'url'] }
          end
        end

        context 'when item is specified with only options' do
          context 'and options do not contain any condition' do
            it_behaves_like 'adding the item to the list' do
              let(:args) { ['key', 'name', { option: true }] }
            end
          end

          context 'and options contains a negative condition' do
            it_behaves_like "doesn't add the item to the list" do
              let(:args) { ['key', 'name', { if: ->{ false }, option: true }] }
            end
          end

          context 'and options contains a positive condition' do
            it_behaves_like 'adding the item to the list' do
              let(:args) { ['key', 'name', { if: ->{ true }, option: true }] }
            end
          end
        end

        context 'when item is specified with a url and options' do
          context 'and options do not contain any condition' do
            it_behaves_like 'adding the item to the list' do
              let(:args) { ['key', 'name', 'url', { option: true }] }
            end
          end

          context 'and options contains a negative condition' do
            it_behaves_like "doesn't add the item to the list" do
              let(:args) { ['key', 'name', 'url', { if: ->{ false }, option: true }] }
            end
          end

          context 'and options contains a positive condition' do
            it_behaves_like 'adding the item to the list' do
              let(:args) { ['key', 'name', 'url', { if: ->{ true }, option: true }] }
            end
          end
        end
      end

      describe 'Conditions' do
        context 'when an :if option is given' do
          let(:options) {{ if: proc{condition} }}
          let(:condition) { nil }

          it 'removes :if from the options' do
            item_container.item('key', 'name', 'url', options)
            expect(options).not_to have_key(:if)
          end

          context 'and it evals to true' do
            let(:condition) { true }

            it 'creates a new Navigation-Item' do
              expect(Item).to receive(:new)
              item_container.item('key', 'name', 'url', options)
            end
          end

          context 'and it evals to false' do
            let(:condition) { false }

            it "doesn't create a new Navigation-Item" do
              expect(Item).not_to receive(:new)
              item_container.item('key', 'name', 'url', options)
            end
          end

          context 'and it is not a proc or a method' do
            it 'raises an error' do
              expect{
                item_container.item('key', 'name', 'url', { if: 'text' })
              }.to raise_error
            end
          end
        end

        context 'when an :unless option is given' do
          let(:options) {{ unless: proc{condition} }}
          let(:condition) { nil }

          it "removes :unless from the options" do
            item_container.item('key', 'name', 'url', options)
            expect(options).not_to have_key(:unless)
          end

          context 'and it evals to false' do
            let(:condition) { false }

            it 'creates a new Navigation-Item' do
              expect(Item).to receive(:new)
              item_container.item('key', 'name', 'url', options)
            end
          end

          context 'and it evals to true' do
            let(:condition) { true }

            it "doesn't create a new Navigation-Item" do
              expect(Item).not_to receive(:new)
              item_container.item('key', 'name', 'url', options)
            end
          end
        end
      end
    end

    describe '#[]' do
      before do
        item_container.item(:first, 'first', 'bla')
        item_container.item(:second, 'second', 'bla')
        item_container.item(:third, 'third', 'bla')
      end

      it 'returns the item with the specified navi_key' do
        expect(item_container[:second].name).to eq 'second'
      end

      context 'when no item exists for the specified navi_key' do
        it 'returns nil' do
          expect(item_container[:invalid]).to be_nil
        end
      end
    end

    describe '#render' do
      # TODO
      let(:renderer_instance) { double(:renderer).as_null_object }
      let(:renderer_class) { double(:renderer_class, new: renderer_instance) }

      context 'when renderer is specified as an option' do
        context 'and is specified as a class' do
          it 'instantiates the passed renderer_class with the options' do
            expect(renderer_class).to receive(:new)
                                      .with(renderer: renderer_class)
            item_container.render(renderer: renderer_class)
          end

          it 'calls render on the renderer and passes self' do
            expect(renderer_instance).to receive(:render).with(item_container)
            item_container.render(renderer: renderer_class)
          end
        end

        context 'and is specified as a symbol' do
          before do
            SimpleNavigation.registered_renderers = {
              my_renderer: renderer_class
            }
          end

          it "instantiates the passed renderer_class with the options" do
            expect(renderer_class).to receive(:new).with(renderer: :my_renderer)
            item_container.render(renderer: :my_renderer)
          end

          it 'calls render on the renderer and passes self' do
            expect(renderer_instance).to receive(:render).with(item_container)
            item_container.render(renderer: :my_renderer)
          end
        end
      end

      context 'when no renderer is specified' do
        let(:options) { Hash.new }

        before { item_container.stub(renderer: renderer_class) }

        it "instantiates the container's renderer with the options" do
          expect(renderer_class).to receive(:new).with(options)
          item_container.render(options)
        end

        it 'calls render on the renderer and passes self' do
          expect(renderer_instance).to receive(:render).with(item_container)
          item_container.render(options)
        end
      end
    end

    describe '#level_for_item' do
      before(:each) do
        item_container.item(:p1, 'p1', 'p1')
        item_container.item(:p2, 'p2', 'p2') do |p2|
          p2.item(:s1, 's1', 's1')
          p2.item(:s2, 's2', 's2') do |s2|
            s2.item(:ss1, 'ss1', 'ss1')
            s2.item(:ss2, 'ss2', 'ss2')
          end
          p2.item(:s3, 's3', 's3')
        end
        item_container.item(:p3, 'p3', 'p3')
      end

      shared_examples 'returning the level of an item' do |item, level|
        specify{ expect(item_container.level_for_item(item)).to eq level }
      end

      it_behaves_like 'returning the level of an item', :p1, 1
      it_behaves_like 'returning the level of an item', :p3, 1
      it_behaves_like 'returning the level of an item', :s1, 2
      it_behaves_like 'returning the level of an item', :ss1, 3
      it_behaves_like 'returning the level of an item', :x, nil
    end

    describe '#empty?' do
      context 'when there are no items' do
        it 'returns true' do
          item_container.instance_variable_set(:@items, [])
          expect(item_container).to be_empty
        end
      end

      context 'when there are some items' do
        it 'returns false' do
          item_container.instance_variable_set(:@items, [double(:item)])
          expect(item_container).not_to be_empty
        end
      end
    end
  end
end
