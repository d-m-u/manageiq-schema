require_migration

describe AddAncestryToVm do
  let(:rel_stub) { migration_stub(:Relationship) }
  let(:vm_stub) { migration_stub :VmOrTemplate }
  let(:vm) { vm_stub.create! }
  let(:all_relationships) { rel_stub.all }

  migration_context :up do
    context "parent/child/grandchild rel" do
      #         parent
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

    context "with only ems_metadata relationship tree" do
      it 'sets nothing' do
        parent = vm_stub.create!
        child = vm_stub.create!
        parent_rel = create_rel(parent, 'ems_metadata')
        create_rel(child, 'ems_metadata', ancestry_for(parent_rel))
        vm

        migrate

        expect(vm.reload.ancestry).to eq(nil)
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
    context "covalent bond" do
      let(:vm) { vm_stub.create }
      let(:child) { vm_stub.create(:ancestry => ancestry_for(vm)) }
      it 'creates rel and removes ancestry' do
        vm
        child

        migrate

        vm_rel = find_rel(vm)
        child_rel = find_rel(child)
        expect(child_rel.relationship).to eq('genealogy')
        expect(child_rel.ancestry).to eq(vm_rel.id.to_s)
        expect(child_rel.resource_type).to eq('VmOrTemplate')
        expect(child_rel.resource_id).to eq(child.id)
        expect(vm_rel.relationship).to eq('genealogy')
        expect(vm_rel.ancestry).to eq(nil)
        expect(vm_rel.resource_type).to eq('VmOrTemplate')
        expect(vm_rel.resource_id).to eq(vm.id)
      end
    end

    context "complicated tree" do
      it 'updates ancestry' do
        #           a
        #      b         c
        #      d         g
        #    e   f
        a = vm_stub.create!
        b = vm_stub.create!(:ancestry => ancestry_for(a))
        c = vm_stub.create!(:ancestry => ancestry_for(a))
        d = vm_stub.create!(:ancestry => ancestry_for(b, a))
        e = vm_stub.create!(:ancestry => ancestry_for(d, b, a))
        f = vm_stub.create!(:ancestry => ancestry_for(d, b, a))
        g = vm_stub.create!(:ancestry => ancestry_for(c, a))

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

  def ancestry_for(*nodes)
    nodes.map(&:id).join("/").presence
  end

  def create_rel(resource, relationship, ancestors = nil)
    rel_stub.create!(:relationship => relationship, :ancestry => ancestors.nil? ? nil : ancestors, :resource_type => 'VmOrTemplate', :resource_id => resource.id)
  end

  def find_rel(obj)
    all_relationships.detect { |r| r.resource_id == obj.id }
  end
end
