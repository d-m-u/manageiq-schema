require_migration

describe AddAncestryToVm do
  let(:rel_stub) { migration_stub(:Relationship) }
  let(:vm_stub) { migration_stub :VmOrTemplate }
  let(:vm) { vm_stub.create! }
  let(:default_rel_type) { 'genealogy' }

  migration_context :up do
    context "parent/child/grandchild rel" do
      #         parent
      #         child
      #       grandchild
      it 'updates ancestry' do
        tree = create_tree(:parent => {:child => :grandchild})
        parent, child, grandchild = tree[:parent], tree[:child], tree[:grandchild]

        migrate

        expect(parent.reload.ancestry).to eq(nil)
        expect(child.reload.ancestry).to eq(ancestry_for(parent))
        expect(grandchild.reload.ancestry).to eq(ancestry_for(child, parent))
        expect(rel_stub.count).to eq(0)
      end
    end

    context "complicated tree" do
      it 'updates ancestry' do
        #           a
        #      b         c
        #      d         g
        #    e   f
        tree = create_tree(:a => [{:c => :g}, {:b => {:d => [:e, :f]}}])
        a, b, c, d, e, f, g = tree[:a], tree[:b], tree[:c], tree[:d], tree[:e], tree[:f], tree[:g]

        migrate

        expect(a.reload.ancestry).to eq(nil)
        expect(b.reload.ancestry).to eq(ancestry_for(a))
        expect(c.reload.ancestry).to eq(ancestry_for(a))
        expect(g.reload.ancestry).to eq(ancestry_for(c, a))
        expect(e.reload.ancestry).to eq(ancestry_for(d, b, a))
        expect(f.reload.ancestry).to eq(ancestry_for(d, b, a))
        expect(rel_stub.count).to eq(0)
      end
    end

    context "vm without rels" do
      it 'nil ancestry' do
        migrate

        expect(vm_stub.find(vm.id).ancestry).to eq(nil)
      end
    end

    context "with only ems_metadata relationship tree" do
      let(:default_rel_type) { 'ems_metadata' }
      it 'does not set vm ancestry' do
        tree = create_tree(:parent => :child)
        parent, child = tree[:parent], tree[:child]

        migrate

        expect(child.reload.ancestry).to eq(nil)
        expect(parent.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(2)
      end
    end
  end

  migration_context :down do
    context "complicated tree" do
      it 'updates ancestry' do
        #           a
        #      b         c
        #      d         g
        #    e   f
        tree = create_tree(:a => [{:c => :g}, {:b => {:d => [:e, :f]}}])
        a, b, c, d, e, f, g = tree[:a], tree[:b], tree[:c], tree[:d], tree[:e], tree[:f], tree[:g]

        migrate

        expect(find_rel(a).ancestry).to eq(nil)
        expect(find_rel(b).ancestry).to eq(ancestry_for(find_rel(a)))
        expect(find_rel(c).ancestry).to eq(ancestry_for(find_rel(a)))
        expect(find_rel(g).ancestry).to eq(ancestry_for(find_rel(c), find_rel(a)))
        expect(find_rel(e).ancestry).to eq(ancestry_for(find_rel(d), find_rel(b), find_rel(a)))
        expect(find_rel(f).ancestry).to eq(ancestry_for(find_rel(d), find_rel(b), find_rel(a)))
        expect(rel_stub.count).to eq(7)
      end
    end

  end

  private

  def ancestry_for(*nodes)
    nodes.map(&:id).presence.join("/")
  end

  def find_rel(obj)
    rel_stub.all.detect { |r| r.resource_id == obj.id }
  end

  def create_tree(tree, relationship = default_rel_type)
    resources = {}
    traverse(tree, []) { |_, id| resources.merge!(id => vm_stub.create!) }

    traverse(tree, []) do |parents, id|
      ancestry = if parents.present?
        parents.reverse.map { |s| rel_stub.find_by(:resource_id => resources[s].id).id }.compact.join('/')
      else
        nil
      end
      rel_stub.create!(:ancestry => ancestry, :resource_id => resources[id].id, :resource_type => 'VmOrTemplate', :relationship => relationship)
    end

    resources
  end

  def traverse(tree, parent, &block)
    case tree
    when Symbol || String
      yield(parent, tree)
    when Array
      tree.each { |node| traverse(node, parent, &block) }
    when Hash
      tree.each do |key, children|
        yield(parent, key)
        traverse(children, parent + [key], &block)
      end
    else
      "oh no"
    end
  end
end
