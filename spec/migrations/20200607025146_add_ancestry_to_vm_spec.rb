require_migration

describe AddAncestryToVm do
  let(:rel_stub) { migration_stub(:Relationship) }
  let(:vm_stub) { migration_stub :VmOrTemplate }
  let(:vm) { vm_stub.create! }

  migration_context :up do
    context "parent/child/grandchild rel" do
      #           a
      #         child
      #       grandchild
      it 'updates ancestry' do
        parent = vm_stub.create!
        child = vm_stub.create!
        grandchild = vm_stub.create!
        parent_rel = create_rel(parent, 'genealogy')
        child_rel = create_rel(child, 'genealogy', ancestry_for(parent_rel))
        create_rel(grandchild, 'genealogy', ancestry_for(child_rel, parent_rel))

        migrate

        expect(child.reload.ancestry).to eq(ancestry_for(parent))
        expect(grandchild.reload.ancestry).to eq(ancestry_for(child, parent))
        expect(parent.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(0)
      end
    end

    context "complicated tree" do
      it 'updates ancestry' do
        #           a
        #      b         c
        #      d         g
        #    e   f
        a = vm_stub.create!
        b = vm_stub.create!
        c = vm_stub.create!
        d = vm_stub.create!
        e = vm_stub.create!
        f = vm_stub.create!
        g = vm_stub.create!

        a_rel = create_rel(a, 'genealogy')
        b_rel = create_rel(b, 'genealogy', ancestry_for(a_rel))
        c_rel = create_rel(c, 'genealogy', ancestry_for(a_rel))
        d_rel = create_rel(d, 'genealogy', ancestry_for(b_rel, a_rel))
        create_rel(e, 'genealogy', ancestry_for(d_rel, b_rel, a_rel))    # e_rel
        create_rel(f, 'genealogy', ancestry_for(d_rel, b_rel, a_rel))    # f_rel
        create_rel(g, 'genealogy', ancestry_for(c_rel, a_rel))           # g_rel

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
      it 'sets nothing' do
        parent = vm_stub.create!
        child = vm_stub.create!
        parent_rel = create_rel(parent, 'ems_metadata')
        create_rel(child, 'ems_metadata', ancestry_for(parent_rel))

        migrate

        expect(child.reload.ancestry).to eq(nil)
        expect(parent.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(2)
      end
    end

    context "with both genealogy and ems_metadata rels" do
      it 'only sets ancestry from genealogy rels' do
        parent = vm_stub.create!
        child = vm_stub.create!
        ems_metadata_parent = vm_stub.create!
        ems_metadata_child = vm_stub.create!
        ems_metadata_parent_rel = create_rel(ems_metadata_parent, 'ems_metadata')
        create_rel(ems_metadata_child, 'ems_metadata', ancestry_for(ems_metadata_parent_rel))   # ems_metadata_child_rel
        parent_rel = create_rel(parent, 'genealogy')
        create_rel(child, 'genealogy', ancestry_for(parent_rel))                                # child_rel

        migrate

        expect(child.reload.ancestry).to eq(ancestry_for(parent))
        expect(parent.reload.ancestry).to eq(nil)
        expect(rel_stub.count).to eq(2)
      end
    end
  end

  migration_context :down do
    context "multiple rels" do
      let!(:vm) { vm_stub.create!(:ancestry => '6/5/4') }
      it 'creates rel and removes ancestry' do
        migrate

        rel = rel_stub.first
        expect(rel.relationship).to eq('genealogy')
        expect(rel.ancestry).to eq('6/5/4')
        expect(rel.resource_type).to eq('VmOrTemplate')
        expect(rel.resource_id).to eq(vm.id)
      end
    end

    context "single rel" do
      let!(:vm) { vm_stub.create!(:ancestry => '645') }
      it 'creates rel and removes ancestry' do
        migrate

        rel = rel_stub.first
        expect(rel.relationship).to eq('genealogy')
        expect(rel.ancestry).to eq('645')
        expect(rel.resource_type).to eq('VmOrTemplate')
        expect(rel.resource_id).to eq(vm.id)
      end
    end
  end

  def ancestry_for(*nodes)
    nodes.map(&:id).join("/").presence
  end

  def create_rel(resource, relationship, ancestors = nil)
    rel_stub.create!(:relationship => relationship, :ancestry => ancestors.nil? ? nil : ancestors, :resource_type => 'VmOrTemplate', :resource_id => resource.id)
  end
end
